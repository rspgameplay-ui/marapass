import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.95.0';
const supabase=createClient('https://nwwxobiqynawxxnbvubz.supabase.co',
  '__SUPABASE_PUBLISHABLE_KEY__',{
  auth:{detectSessionInUrl:true,persistSession:true,autoRefreshToken:true}
});
const $=id=>document.getElementById(id);
const visible=(id,on)=>$(id).classList.toggle('hidden',!on);
const report=(message,kind='')=>{const s=$('partnerStatus');s.textContent=message;s.className='status '+kind;};
let busy=false;
async function refreshInvitationPage(){
 const {data:{user},error}=await supabase.auth.getUser();
 if(error||!user){visible('loginPartnerSection',true);visible('partnerInvitationsSection',false);report('Entre com o e-mail convidado para ver suas empresas.');return;}
 if(!user.email_confirmed_at){report('E-mail ainda não confirmado. Utilize o link de confirmação recebido na sua caixa de entrada.','error');return;}
 visible('loginPartnerSection',false);visible('partnerInvitationsSection',true);
 $('signedEmail').textContent='Conta confirmada: '+user.email;
 await loadInvitations();
}
async function loadInvitations(){
 report('Consultando os convites vinculados ao e-mail confirmado…');
 const {data,error}=await supabase.functions.invoke('marapass-partner-invitations',{body:{action:'list'}});
 if(error||!data?.success){report('Não foi possível consultar seus convites. Verifique a sessão e tente novamente.','error');return;}
 const root=$('partnerCards');root.replaceChildren();
 const invitations=Array.isArray(data.invitations)?data.invitations:[];
 if(!invitations.length){
  const p=document.createElement('p');p.className='empty-message';p.textContent='Ainda não encontramos convites para este e-mail. Peça ao administrador que confira o endereço informado e envie o convite.';root.appendChild(p);
 } else for(const item of invitations){
  const card=document.createElement('article');card.className='partner-invite-card';
  const title=document.createElement('h3');title.textContent=item.trade_name;
  const details=document.createElement('p');details.className='muted';
  const expired=item.status==='sent'&&item.expires_at&&new Date(item.expires_at).getTime()<=Date.now();
  details.textContent=item.status==='accepted' && item.partner_status==='approved'?'Empresa ativada pelo administrador. O catálogo será configurado em outra etapa.':item.status==='accepted'?'Convite aceito · aguardando aprovação comercial':expired?'Convite expirado. Solicite um novo envio.':'Convite para vincular sua conta verificada a esta empresa.';
  card.append(title,details);
  if(item.status==='sent'&&!expired){
   const button=document.createElement('button');button.className='primary';button.type='button';button.textContent='Aceitar vínculo com a empresa';
   button.addEventListener('click',()=>acceptInvite(item.partner_id,button));card.append(button);
  }else if(item.status==='accepted'){
   const tag=document.createElement('span');tag.className='invite-tag';tag.dataset.status='accepted';tag.textContent=item.partner_status==='approved'?'Parceiro ativado':'E-mail confirmado e vínculo aceito';card.append(tag);
  }
  root.append(card);
 }
 report('Convites consultados. Revise a empresa antes de aceitar a vinculação.','success');
}
async function acceptInvite(partnerId,button){
 if(busy)return;
 if(!confirm('Confirma que você é o responsável pela empresa indicada e deseja vinculá-la à sua conta MaraPass?'))return;
 busy=true;button.disabled=true;report('Confirmando a vinculação com segurança…');
 try{
  const {data,error}=await supabase.functions.invoke('marapass-partner-invitations',{body:{action:'accept',partnerId}});
  if(error||!data?.success)throw new Error('Convite indisponível ou expirado. Peça ao administrador que reenvie o convite.');
  await loadInvitations();report('Vínculo aceito. Seu e-mail está confirmado. Aguarde a aprovação comercial do administrador.','success');
 }catch(e){report(e.message||'Não foi possível concluir.','error');}
 finally{busy=false;button.disabled=false;}
}
$('partnerLoginForm').addEventListener('submit',async e=>{
 e.preventDefault();if(busy)return;busy=true;$('partnerLoginButton').disabled=true;
 try{
  const email=$('partnerEmail').value.trim();const password=$('partnerPassword').value;
  if(!password){report('Informe sua senha ou selecione Receber link por e-mail.','error');return;}
  const {error}=await supabase.auth.signInWithPassword({email,password});
  $('partnerPassword').value='';if(error)throw new Error('Não foi possível entrar. Confira sua senha ou solicite um link.');
  await refreshInvitationPage();
 }catch(e){report(e.message,'error');}finally{busy=false;$('partnerLoginButton').disabled=false;}
});
$('partnerSendLink').addEventListener('click',async()=>{
 if(busy)return;const email=$('partnerEmail').value.trim();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)){report('Digite um e-mail válido.','error');return;}
 busy=true;$('partnerSendLink').disabled=true;
 try{
  const {error}=await supabase.auth.signInWithOtp({email,options:{shouldCreateUser:false,emailRedirectTo:'https://marapass-admin-dev.pages.dev/parceiro.html'}});
  if(error)throw error;
  report('Se a conta estiver cadastrada, você receberá um link de acesso. Confira seu e-mail e a pasta de spam.','success');
 }catch{report('Não foi possível solicitar o link agora. Confira as configurações de e-mail ou tente mais tarde.','error');}
 finally{busy=false;$('partnerSendLink').disabled=false;}
});
$('partnerPasswordForm').addEventListener('submit',async e=>{
 e.preventDefault();if(busy)return;
 const password=$('partnerNewPassword').value;
 if(password.length<12||password!==$('partnerConfirmPassword').value){report('Use pelo menos 12 caracteres e digite duas senhas iguais.','error');return;}
 busy=true;$('partnerSavePassword').disabled=true;
 try{
  const {error}=await supabase.auth.updateUser({password});if(error)throw error;
  $('partnerNewPassword').value='';$('partnerConfirmPassword').value='';report('Senha definida com sucesso. Guarde-a em local seguro.','success');
 }catch{report('Não foi possível definir a senha. Verifique as regras de segurança e tente novamente.','error');}
 finally{busy=false;$('partnerSavePassword').disabled=false;}
});
$('partnerReload').addEventListener('click',loadInvitations);
$('partnerSignOut').addEventListener('click',async()=>{await supabase.auth.signOut({scope:'local'});await refreshInvitationPage();});
// Processa automaticamente links válidos enviados pelo Supabase Auth.
refreshInvitationPage().catch(()=>report('Não foi possível validar o link. Faça login e tente novamente.','error'));
