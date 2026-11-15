const {test}=require('node:test');const assert=require('node:assert/strict');
const {normalizeCommand:n,adaptResults,install}=require('../../web/voice/recognition_adapter.js');
for(const [input,want]of [
 ['vamos à praia do Olho d\'Água',"rota para Olho d'Água"],
 ['me leva pra praia do olho dagua',"rota para Olho d'Água"],
 ['eu gostaria de ir para Barreirinhas','rota para Barreirinhas'],
 ['você pode me mostrar restaurantes em São Luiz','localize restaurantes em São Luís'],
 ['onde fica a Igreja do Desterro','localize a Igreja do Desterro'],
 ['não, eu falei Santo Amaro','localize Santo Amaro'],
 ['localize restaurante em Barreirinhas com cupons dia 20 de janeiro','localize restaurante em Barreirinhas com cupons dia 20 de janeiro'],
 ['sim','sim'],['cancelar','cancelar'],['a segunda opção','a segunda opção'],
 ['vamos à praia Marte Secreta','rota para praia Marte Secreta']])test(input,()=>assert.equal(n(input),want));
test('a gente vai para os Lençóis Maranhenses',()=>assert.equal(n('a gente vai para os Lençóis Maranhenses'),'rota para Lençóis Maranhenses'));
test('relative date uses Fortaleza and handles month boundary',()=>assert.equal(n('cupons em Barreirinhas depois de amanhã',new Date('2026-12-31T02:00:00Z')),'cupons em Barreirinhas 1/1/2027'));
test('whole phrase across multiple ASR segments, preserves first alternative',()=>{
 const result=adaptResults({results:[Object.assign([{transcript:'me leva pra',confidence:.8},{transcript:'igreja',confidence:.7}],{isFinal:true}),Object.assign([{transcript:'praia do olho dagua',confidence:.9}],{isFinal:false})]});
 assert.equal(result.results.item(0).item(0).transcript,"rota para Olho d'Água");assert.equal(result.results[0].isFinal,false);
});
function browser(){let native;class Speech {constructor(){native=this;}start(){this.started=true;}stop(){this.stopped=true;this.onend?.({});}abort(){this.aborted=true;this.onend?.({});}}let seq=0;const timers=new Map();return {target:{SpeechRecognition:Speech,setTimeout:(f,ms)=>{timers.set(++seq,{f,ms});return seq},clearTimeout:i=>timers.delete(i)},get native(){return native},timers};}
test('standard-only browser gets prefixed constructor and forwards plugin callbacks',()=>{
 const b=browser();assert.equal(install(b.target),true);const r=new b.target.webkitSpeechRecognition();let got;
 r.onresult=e=>got=e.results[0][0].transcript;r.start();assert.equal(b.native.lang,'pt-BR');assert.equal(b.native.maxAlternatives,3);
 b.native.onresult({results:[Object.assign([{transcript:'me leva para São Luiz',confidence:.9}],{isFinal:true})]});assert.equal(got,'rota para São Luís');
 r.abort();assert.equal(b.native.aborted,true);assert.equal(b.timers.size,0);
});
test('stop clears timers and end callback is delivered once',()=>{const b=browser();install(b.target);const r=new b.target.SpeechRecognition();let ends=0;r.onend=()=>ends++;r.start();r.stop();assert.equal(ends,1);assert.equal(b.timers.size,0)});
test('no unsupported fake recognition and no double wrapping',()=>{assert.equal(install({}),false);const b=browser();install(b.target);const ctor=b.target.SpeechRecognition;assert.equal(install(b.target),false);assert.equal(b.target.SpeechRecognition,ctor)});

test('permission error clears timers and reaches existing UI',()=>{const b=browser();install(b.target);const r=new b.target.SpeechRecognition();let error;r.onerror=e=>error=e.error;r.start();b.native.onerror({error:'not-allowed'});assert.equal(error,'not-allowed');assert.equal(b.timers.size,0)});
test('empty ASR result is ignored',()=>{const b=browser();install(b.target);const r=new b.target.SpeechRecognition();let calls=0;r.onresult=()=>calls++;b.native.onresult({results:[]});assert.equal(calls,0);r.abort()});

for(const spoken of ['Aracagy','Aracagi','Aracaji','Arassagi','Arasaji'])test('voice beach spelling '+spoken,()=>assert.equal(n('vamos à Praia do '+spoken),'rota para Praia do Araçagy'));
