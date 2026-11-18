"""Integração em PostgreSQL descartável (MARA_TEST_DSN), com usuários sintéticos."""
import os
import unittest
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from pathlib import Path
from threading import Barrier
from uuid import uuid4

import psycopg
from psycopg.types.json import Jsonb

ROOT = Path(__file__).resolve().parents[1]
DSN = os.environ["MARA_TEST_DSN"]


@contextmanager
def session(user=None, role=None, aal="aal1"):
    with psycopg.connect(DSN) as db:
        if role:
            assert role in {"authenticated", "anon", "service_role"}
            db.execute("set local role " + role)
        if user:
            db.execute("select set_config('test.uid',%s,true),set_config('test.aal',%s,true)", (str(user), aal))
        yield db


def one(sql, args=(), user=None, role=None, aal="aal1"):
    with session(user, role or ("authenticated" if user else None), aal) as db:
        return db.execute(sql, args).fetchone()[0]


def account(partner=False):
    uid = uuid4()
    phone = "5598" + str(uid.int)[-9:]
    one("insert into auth.users values (%s,%s,now()) returning id", (uid, phone))
    if partner:
        one("insert into public.mvp_partner_members values(%s) returning user_id", (uid,))
    return uid


class CouponTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with psycopg.connect(DSN) as db:
            assert db.info.host in {"localhost", "127.0.0.1", "::1"} and db.info.dbname == "marapass_coupon_test"
            assert db.execute("select to_regnamespace('auth') is null").fetchone()[0], "Base de testes deve estar vazia."
            db.execute((ROOT / "tests/coupon_fixture.sql").read_text())
        for name in ("commerce", "whatsapp", "operations"):
            with psycopg.connect(DSN, autocommit=True) as db:
                db.execute(next((ROOT / "migrations").glob("*_mvp_coupon_" + name + ".sql")).read_text())

    def setUp(self):
        self.t, self.p, self.admin = account(), account(True), account()
        one("insert into private.test_admins values(%s) returning id", (self.admin,))

    def offer(self, price=10000, kind="percent", discount=1000, limit=5, per=1, eligible=True, approve=True):
        offer = Jsonb(dict(title="Hospedagem teste", rules="Uma diária", limit=limit, until="2099-12-31", category="hospedagem"))
        terms = Jsonb(dict(price=price, kind=kind, discount=discount, points=eligible, per_user=per,
                          payment="Pagar ao parceiro de teste", url="https://example.org/pagar"))
        oid = one("select (public.mvp_create_sale_offer(%s,%s)).id", (offer, terms), self.p)
        if approve:
            with session(self.admin, aal="aal2") as db:
                db.execute("update public.mvp_partner_offers set status='Ativa' where id=%s", (oid,))
        return oid

    def issue(self, oid, uid=None):
        return one("select (public.mvp_activate_offer_coupon(%s)).code", (oid,), uid or self.t)

    def confirm(self, code, amount, uid=None):
        return one("select public.mvp_validate_coupon(%s,%s)", (code, amount), uid or self.p)

    def statement(self, code, who=None, scope="tourist"):
        return one("select public.mvp_coupon_statement(%s,%s)", (scope, code), who or self.t)

    def refund(self, code, amount, ref="R1"):
        one("select public.mvp_refund_coupon(%s,%s,%s,'devolução comprovada')", (code, amount, ref), self.p)

    def simultaneous(self, a, b):
        gate = Barrier(2)
        def invoke(fn):
            gate.wait(timeout=5)
            try:
                return fn()
            except psycopg.Error:
                return None
        with ThreadPoolExecutor(max_workers=2) as pool:
            return list(pool.map(invoke, [a, b]))

    def test_percent_fixed_and_payment_report(self):
        for price, kind, discount, due, fee in [(10000,"percent",1000,9000,450),(12000,"fixed",2000,10000,500)]:
            code = self.issue(self.offer(price,kind,discount))
            self.assertEqual((self.statement(code)["state"],self.statement(code)["fee"]),("issued",0))
            one("select public.mvp_report_payment(%s)",(code,),self.t)
            self.assertEqual((self.statement(code)["state"],self.statement(code)["fee"]),("payment_reported",0))
            self.assertTrue(self.confirm(code,due)["ok"])
            self.assertEqual((self.statement(code)["fee"],self.statement(code)["points"]),(fee,due//100))

    def test_exact_half_cent_and_noneligible(self):
        # 101 × 50% = 50,5 centavos de desconto; 50 × 5% = 2,5 centavos de comissão.
        code=self.issue(self.offer(101,"percent",5000,eligible=False))
        self.confirm(code,50)
        self.assertEqual((self.statement(code)["sale"]["discount_cents"],self.statement(code)["fee"]),(51,3))
        code=self.issue(self.offer(1111,"fixed",1,eligible=False))
        self.confirm(code,1110)
        self.assertEqual(self.statement(code)["points"],0)

    def test_competing_confirmations_and_issuance(self):
        oid=self.offer(limit=1)
        codes=self.simultaneous(lambda:self.issue(oid),lambda:self.issue(oid))
        self.assertIsNotNone(codes[0]);self.assertEqual(codes[0],codes[1])
        code=codes[0]
        confirmations=self.simultaneous(lambda:self.confirm(code,9000),lambda:self.confirm(code,9000))
        self.assertTrue(all(r["ok"] for r in confirmations))
        self.assertEqual(len(self.statement(code)["entries"]),1)
        with self.assertRaises(psycopg.Error):
            self.issue(oid,account())
        with self.assertRaises(psycopg.Error):
            self.issue(oid)

    def test_competing_last_unit_and_per_user(self):
        oid=self.offer(limit=1)
        t2=account()
        codes=self.simultaneous(lambda:self.issue(oid),lambda:self.issue(oid,t2))
        self.assertEqual(len([c for c in codes if c]),1)
        oid=self.offer(per=2)
        for _ in range(2): self.confirm(self.issue(oid),9000)
        with self.assertRaises(psycopg.Error):self.issue(oid)

    def test_access_expiry_and_mismatch(self):
        code=self.issue(self.offer()); other=account(True)
        self.assertFalse(self.confirm(code,9000,other)["ok"])
        self.assertEqual(one("select count(*) from public.mvp_coupons where code=%s",(code,),other),0)
        with self.assertRaises(psycopg.Error): one("select public.mvp_report_payment(%s)",(code,),other)
        self.assertFalse(self.confirm(code,8999)["ok"])
        self.assertEqual(self.statement(code)["events"][-1]["kind"],"amount_mismatch")
        self.assertEqual(self.statement(code)["entries"],[])
        one("""update public.mvp_coupons set sale=jsonb_set(sale,'{expires}',to_jsonb(now()-interval '1 second'))
          where code=%s returning id""",(code,))
        self.assertEqual(self.confirm(code,9000)["reason"],"expired")
        with self.assertRaises(psycopg.Error):self.statement(code,self.p,"admin")
        with self.assertRaises(psycopg.Error):self.statement(code,self.admin,"admin")
        self.assertEqual(one("select public.mvp_coupon_statement('admin',%s)",(code,),self.admin,aal="aal2")["code"],code)

    def test_approval_legacy_and_snapshot(self):
        oid=self.offer(approve=False)
        with self.assertRaises(psycopg.Error):self.issue(oid)
        with self.assertRaises(psycopg.Error):one("select public.mvp_set_offer_status(%s,'Ativa')",(oid,),self.p)
        with self.assertRaises(psycopg.Error):one("select public.mvp_activate_coupon('editorial')",user=self.t)
        oid=self.offer();code=self.issue(oid)
        one("select public.mvp_set_sale_terms(%s,12000,'fixed',100,'Pix de teste',null)",(oid,),self.p)
        with self.assertRaises(psycopg.Error):self.issue(oid,account())
        self.assertTrue(self.confirm(code,9000)["ok"])
        legacy=one("insert into public.mvp_coupons(user_id,cupom_key,code) values(%s,'legacy',%s) returning code",(self.t,str(uuid4())))
        self.assertFalse(self.confirm(legacy,1000)["ok"])

    def test_partial_full_and_replayed_refund(self):
        code=self.issue(self.offer(1011,"fixed",1));self.confirm(code,1010)
        self.assertEqual(self.statement(code)["fee"],51)
        self.refund(code,11);self.refund(code,11)
        row=self.statement(code)
        self.assertEqual((row["state"],row["paid"],row["fee"],row["points"]),("partial_refund",999,50,9))
        with self.assertRaises(psycopg.Error):self.refund(code,12)
        with self.assertRaises(psycopg.Error):self.refund(code,1000,"R2")
        self.refund(code,999,"R2")
        row=self.statement(code)
        self.assertEqual((row["state"],row["fee"],row["points"]),("refunded",0,0))
        self.assertEqual([e["paid_cents"] for e in row["entries"]],[1010,-11,-999])
        self.assertTrue(self.confirm(code,1010)["already"])
        self.assertEqual(one("select sum(points) from public.mvp_coupon_points()",user=self.t),0)

    def action(self, code, action, user=None, channel="panel", note="conferido"):
        return one("select public.mvp_coupon_action(%s,%s,%s,%s)",(code,action,note,channel),user or self.p,
                   aal="aal2" if channel=="admin" else "aal1")

    def test_dispute_fulfillment_and_commission_lifecycle(self):
        code=self.issue(self.offer())
        self.assertEqual(self.confirm(code,100)["reason"],"amount_mismatch")
        self.assertEqual(self.confirm(code,9000)["reason"],"disputed")
        self.action(code,"resolve")
        result=one("select public.mvp_confirm_receipt(%s,9000,'whatsapp')",(code,),self.p)
        self.assertTrue(result["ok"])
        self.assertEqual(self.statement(code,self.p,"partner")["events"][-1]["detail"]["channel"],"whatsapp")
        self.action(code,"utilize");self.action(code,"complete")
        self.assertEqual(self.statement(code)["state"],"completed")
        with self.assertRaises(psycopg.Error):self.action(code,"fee_paid",self.p)
        self.action(code,"fee_invoiced",self.admin,"admin");self.action(code,"fee_paid",self.admin,"admin")
        self.assertEqual(self.statement(code)["fee_state"],"paid")
        self.assertEqual(len(self.statement(code)["entries"]),1)

    def test_cancelled_refused_invalid_code_and_promo(self):
        oid=self.offer(price=15000,kind="promo",discount=12450,limit=1)
        code=self.issue(oid)
        self.action(code,"cancel",self.t,"app")
        self.assertFalse(self.confirm(code,12450)["ok"])
        code2=self.issue(oid);self.assertNotEqual(code,code2)
        self.action(code2,"decline")
        self.assertFalse(self.confirm(code2,12450)["ok"])
        code3=self.issue(oid);self.assertEqual(self.statement(code3)["sale"]["discount_cents"],2550)
        self.assertEqual(self.confirm(code3,12450)["fee_cents"],623)
        self.assertFalse(self.confirm("MP-INVALID",100)["ok"])
        for _ in range(30):last=self.confirm("MP-INVALID",100)
        self.assertEqual(last["reason"],"rate_limited")

    def test_public_catalog_date_filters_and_both_notification_events(self):
        oid=self.offer()
        self.assertGreater(one("select count(*) from public.mvp_public_sales() x where x->>'id'=%s",(str(oid),),role="anon"),0)
        for u in [self.t,self.p]:one("select public.mvp_wa_opt(true)",user=u)
        code=self.issue(oid);self.confirm(code,9000);self.confirm(code,9000)
        rows=one("select jsonb_agg(x) from public.mvp_coupon_deliveries(%s,'admin') x",(code,),self.admin,aal="aal2")
        self.assertEqual(sorted((r["event"],r["audience"]) for r in rows),
                         [(e,a) for e in ["converted","issued"] for a in ["partner","tourist"]])
        result=one("select public.mvp_coupon_overview('partner',%s)",(Jsonb({"category":"hospedagem"}),),self.p)
        self.assertEqual((result["issued"],result["ticket"],result["fee"]),(1,9000,450))
        hidden=one("select public.mvp_coupon_overview('partner',%s)",(Jsonb({"until":"2000-01-01"}),),self.p)
        self.assertEqual(hidden["issued"],0)
        with self.assertRaises(psycopg.Error):
            one("select public.mvp_set_sale_terms(%s,10000,'fixed',1,'teste',null,true,1,%s)",
                (oid, Jsonb({"from":"2100-01-01"})),self.p)
        one("select public.mvp_set_sale_terms(%s,10000,'fixed',1,'teste',null,true,1,%s)",
            (oid,Jsonb({"from":"2098-01-01"})),self.p)
        one("select public.mvp_admin_sale_status(%s,'Ativa')",(oid,),self.admin,aal="aal2")
        with self.assertRaises(psycopg.Error):self.issue(oid,account())

    def test_deleted_tourist_preserves_financial_history(self):
        code=self.issue(self.offer());self.confirm(code,9000)
        one("delete from auth.users where id=%s returning id",(self.t,))
        row=self.statement(code,self.p,"partner")
        self.assertEqual((row["state"],row["fee"] ),("converted",450))
        self.assertEqual(one("select user_id is null from public.mvp_coupons where code=%s",(code,)),True)

    def test_opt_in_queue_retry_callback_and_revocation(self):
        for u in [self.t,self.p]:one("select public.mvp_wa_opt(true)",user=u)
        code=self.issue(self.offer())
        with self.assertRaises(psycopg.Error):one("select public.mvp_wa_claim()",user=self.t)
        jobs=one("select public.mvp_wa_claim()",role="service_role")
        self.assertEqual({j["role"] for j in jobs},{"partner","tourist"})
        target=next(j for j in jobs if j["role"]=="tourist")
        one("select public.mvp_wa_finish(%s,%s,'retry',null,'http_503')",(target["id"],target["lease"]),role="service_role")
        one("update private.mvp_wa_queue set next_at=now() where id=%s returning id",(target["id"],))
        retry=one("select public.mvp_wa_claim()",role="service_role")
        self.assertEqual(len(retry),1);self.assertEqual(retry[0]["id"],target["id"])
        for status in ["delivered","delivered","sent"]:
            one("select public.mvp_wa_callback(%s,'wamid.test',%s)",(target["id"],status),role="service_role")
        self.assertEqual(one("select state from private.mvp_wa_queue where id=%s",(target["id"],)),"delivered")
        self.assertEqual(one("select count(*) from private.mvp_wa_callbacks where message_id='wamid.test' and status='delivered'"),1)
        self.assertEqual((self.statement(code)["fee"],self.statement(code)["state"]),(0,"issued"))
        one("select public.mvp_wa_opt(false)",user=self.t)
        code2=self.issue(self.offer())
        self.assertEqual(one("select count(*) from public.mvp_coupon_deliveries(%s,'tourist')",(code2,),self.t),0)
        one("select public.mvp_wa_opt(false)",user=self.p)
        self.assertEqual(one("select public.mvp_wa_claim()",role="service_role"),[])


if __name__ == "__main__":
    unittest.main(verbosity=2)

