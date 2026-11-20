
-- MaraPass V10. Commercial disclosure and passport contract foundation.
ALTER TABLE public.offers
 ADD COLUMN IF NOT EXISTS access_scope text NOT NULL DEFAULT 'public',
 ADD COLUMN IF NOT EXISTS eligible_items text,
 ADD COLUMN IF NOT EXISTS calculation_base text,
 ADD COLUMN IF NOT EXISTS minimum_purchase_cents integer NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS maximum_discount_cents integer,
 ADD COLUMN IF NOT EXISTS fixed_use_policy text NOT NULL DEFAULT 'single_use_no_change',
 ADD COLUMN IF NOT EXISTS issue_until timestamptz,
 ADD COLUMN IF NOT EXISTS convert_until timestamptz,
 ADD COLUMN IF NOT EXISTS use_until timestamptz,
 ADD COLUMN IF NOT EXISTS advance_booking_required boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS commercial_terms_version integer NOT NULL DEFAULT 1,
 ADD COLUMN IF NOT EXISTS disclosure_extra text;

ALTER TABLE public.offers
 ADD CONSTRAINT mp_offer_access_scope CHECK(access_scope IN ('public','passport')),
 ADD CONSTRAINT mp_offer_minimum CHECK(minimum_purchase_cents>=0),
 ADD CONSTRAINT mp_offer_maximum CHECK(maximum_discount_cents IS NULL OR maximum_discount_cents>0),
 ADD CONSTRAINT mp_offer_nominal_policy CHECK(fixed_use_policy='single_use_no_change'),
 ADD CONSTRAINT mp_offer_deadline_sequence CHECK(
   (issue_until IS NULL OR convert_until IS NULL OR issue_until<=convert_until)
   AND (convert_until IS NULL OR use_until IS NULL OR convert_until<=use_until)),
 ADD CONSTRAINT mp_offer_complete_publication CHECK(
   NOT is_published OR (
     length(trim(coalesce(eligible_items,'')))>=3
     AND length(trim(coalesce(calculation_base,'')))>=3
     AND issue_until IS NOT NULL
     AND convert_until IS NOT NULL
     AND use_until IS NOT NULL
     AND (access_scope='public' OR access_scope='passport')
     AND (discount_type<>'fixed' OR fixed_use_policy='single_use_no_change')
   )
 );

CREATE TABLE public.passport_products (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 160),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 15 AND 6000),
 price_cents integer NOT NULL CHECK(price_cents>=100),
 currency char(3) NOT NULL DEFAULT 'BRL' CHECK(currency='BRL'),
 validity_start_rule text NOT NULL CHECK(validity_start_rule IN ('purchase','activation','fixed')),
 duration_days integer CHECK(duration_days BETWEEN 1 AND 730),
 fixed_starts_at timestamptz,
 fixed_ends_at timestamptz,
 activation_deadline_days integer CHECK(activation_deadline_days BETWEEN 1 AND 365),
 booking_explanation text NOT NULL DEFAULT 'O agendamento depende das regras e disponibilidade de cada oferta.',
 included_benefits_explanation text NOT NULL DEFAULT '',
 legal_terms text NOT NULL DEFAULT 'A compra à distância observa o art. 49 do CDC, sem renúncia automática pelo acesso ou emissão de cupom.',
 is_published boolean NOT NULL DEFAULT false,
 terms_version integer NOT NULL DEFAULT 1,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK (
  (validity_start_rule='fixed' AND fixed_starts_at IS NOT NULL AND fixed_ends_at>fixed_starts_at AND duration_days IS NULL)
   OR
  (validity_start_rule IN ('purchase','activation') AND duration_days IS NOT NULL AND fixed_starts_at IS NULL AND fixed_ends_at IS NULL)
 ),
 CHECK (
  validity_start_rule<>'activation' OR activation_deadline_days IS NOT NULL
 )
);
CREATE TABLE public.passport_product_benefits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 product_id uuid NOT NULL REFERENCES public.passport_products(id) ON DELETE RESTRICT,
 offer_id uuid NOT NULL REFERENCES public.offers(id) ON DELETE RESTRICT,
 issue_window_days integer NOT NULL CHECK(issue_window_days BETWEEN 1 AND 730),
 convert_window_days integer NOT NULL CHECK(convert_window_days BETWEEN 1 AND 730),
 use_window_days integer NOT NULL CHECK(use_window_days BETWEEN 1 AND 730),
 max_per_holder integer NOT NULL DEFAULT 1 CHECK(max_per_holder BETWEEN 1 AND 20),
 booking_required boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(product_id,offer_id),
 CHECK(issue_window_days<=convert_window_days AND convert_window_days<=use_window_days)
);
CREATE TABLE public.passport_orders (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 buyer_user_id uuid NOT NULL REFERENCES auth.users(id),
 product_id uuid NOT NULL REFERENCES public.passport_products(id) ON DELETE RESTRICT,
 purchase_intent_key uuid NOT NULL,
 price_cents integer NOT NULL CHECK(price_cents>=0),
 currency char(3) NOT NULL DEFAULT 'BRL' CHECK(currency='BRL'),
 status text NOT NULL DEFAULT 'pending_payment' CHECK(status IN ('pending_payment','paid','cancel_requested','refunded','cancelled')),
 terms_snapshot jsonb NOT NULL CHECK(jsonb_typeof(terms_snapshot)='object'),
 payment_provider text,
 provider_payment_reference text,
 payment_confirmed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(buyer_user_id,purchase_intent_key),
 UNIQUE(provider_payment_reference),
 CHECK(status NOT IN ('paid','cancel_requested','refunded') OR payment_confirmed_at IS NOT NULL),
 CHECK(status NOT IN ('paid','cancel_requested','refunded') OR provider_payment_reference IS NOT NULL)
);
CREATE TABLE public.passport_entitlements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 order_id uuid NOT NULL UNIQUE REFERENCES public.passport_orders(id) ON DELETE RESTRICT,
 user_id uuid NOT NULL REFERENCES auth.users(id),
 product_id uuid NOT NULL REFERENCES public.passport_products(id),
 status text NOT NULL DEFAULT 'pending_activation'
   CHECK(status IN ('pending_activation','active','expired','revoked_refund')),
 purchased_at timestamptz NOT NULL,
 activated_at timestamptz,
 valid_from timestamptz,
 valid_until timestamptz,
 CHECK(valid_until IS NULL OR valid_from IS NULL OR valid_until>valid_from)
);
CREATE TABLE public.passport_entitlement_benefits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 entitlement_id uuid NOT NULL REFERENCES public.passport_entitlements(id) ON DELETE RESTRICT,
 offer_id uuid NOT NULL REFERENCES public.offers(id) ON DELETE RESTRICT,
 terms_snapshot jsonb NOT NULL CHECK(jsonb_typeof(terms_snapshot)='object'),
 issue_until timestamptz,
 convert_until timestamptz,
 use_until timestamptz,
 max_issuances integer NOT NULL CHECK(max_issuances BETWEEN 1 AND 20),
 booking_required boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(entitlement_id,offer_id),
 CHECK(issue_until IS NULL OR convert_until IS NULL OR issue_until<=convert_until),
 CHECK(convert_until IS NULL OR use_until IS NULL OR convert_until<=use_until)
);
CREATE TABLE public.passport_cancellation_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 order_id uuid NOT NULL REFERENCES public.passport_orders(id),
 buyer_user_id uuid NOT NULL REFERENCES auth.users(id),
 reason text,
 status text NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','under_review','refunded','resolved')),
 statutory_withdrawal boolean NOT NULL DEFAULT false,
 requested_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 resolution_notes text,
 UNIQUE(order_id)
);
CREATE TABLE public.passport_benefit_incidents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 entitlement_id uuid NOT NULL REFERENCES public.passport_entitlements(id),
 offer_id uuid NOT NULL REFERENCES public.offers(id),
 reported_by uuid NOT NULL REFERENCES auth.users(id),
 reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 4 AND 2000),
 requested_remedy text CHECK(requested_remedy IN ('fulfillment','equivalent','rescission_refund')),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','under_review','resolved')),
 resolution_notes text,
 created_at timestamptz NOT NULL DEFAULT now(),
 resolved_at timestamptz
);

ALTER TABLE public.coupon_instances
 ADD COLUMN IF NOT EXISTS passport_entitlement_id uuid REFERENCES public.passport_entitlements(id),
 ADD COLUMN IF NOT EXISTS eligible_base_cents integer,
 ADD COLUMN IF NOT EXISTS applied_discount_cents integer;

ALTER TABLE public.coupon_redemptions
 ADD COLUMN IF NOT EXISTS applied_discount_cents integer,
 ADD COLUMN IF NOT EXISTS eligible_base_cents integer;

ALTER TABLE public.coupon_instances
 ADD CONSTRAINT mp_coupon_eligible_base CHECK(eligible_base_cents IS NULL OR eligible_base_cents>=0),
 ADD CONSTRAINT mp_coupon_applied_value CHECK(applied_discount_cents IS NULL OR applied_discount_cents>=0);
ALTER TABLE public.coupon_redemptions
 ADD CONSTRAINT mp_redemption_discount CHECK(applied_discount_cents IS NULL OR applied_discount_cents>=0),
 ADD CONSTRAINT mp_redemption_base CHECK(eligible_base_cents IS NULL OR eligible_base_cents>=0);

DO $block$
DECLARE t text;
BEGIN
 FOR t IN SELECT unnest(ARRAY[
 'passport_products','passport_product_benefits','passport_orders',
 'passport_entitlements','passport_entitlement_benefits',
 'passport_cancellation_requests','passport_benefit_incidents'])
 LOOP EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t); END LOOP;
END $block$;
REVOKE ALL ON public.passport_products,public.passport_product_benefits,
 public.passport_orders,public.passport_entitlements,public.passport_entitlement_benefits,
 public.passport_cancellation_requests,public.passport_benefit_incidents FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.passport_products,public.passport_product_benefits TO anon,authenticated;
CREATE POLICY mp_passports_public_catalog ON public.passport_products FOR SELECT TO anon,authenticated
USING(is_published);
CREATE POLICY mp_passport_benefits_public_catalog ON public.passport_product_benefits FOR SELECT TO anon,authenticated
USING(EXISTS(SELECT 1 FROM public.passport_products p WHERE p.id=product_id AND p.is_published));
GRANT SELECT ON public.passport_orders,public.passport_entitlements,public.passport_entitlement_benefits,
 public.passport_cancellation_requests TO authenticated;
CREATE POLICY mp_my_passport_orders ON public.passport_orders FOR SELECT TO authenticated
USING(buyer_user_id=(SELECT auth.uid()));
CREATE POLICY mp_my_passport_entitlements ON public.passport_entitlements FOR SELECT TO authenticated
USING(user_id=(SELECT auth.uid()));
CREATE POLICY mp_my_passport_entitlement_benefits ON public.passport_entitlement_benefits FOR SELECT TO authenticated
USING(EXISTS(SELECT 1 FROM public.passport_entitlements e WHERE e.id=entitlement_id AND e.user_id=(SELECT auth.uid())));
CREATE POLICY mp_my_passport_cancellations ON public.passport_cancellation_requests FOR SELECT TO authenticated
USING(buyer_user_id=(SELECT auth.uid()));
CREATE INDEX passport_orders_buyer ON public.passport_orders(buyer_user_id,created_at DESC);
CREATE INDEX passport_benefits_offer ON public.passport_product_benefits(offer_id);
CREATE INDEX passport_entitlement_benefits_offer ON public.passport_entitlement_benefits(offer_id);
CREATE INDEX coupon_passport_entitlement_idx ON public.coupon_instances(passport_entitlement_id);
;
