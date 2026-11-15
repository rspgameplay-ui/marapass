/* MaraPass web speech compatibility. No audio/transcript storage or remote NLP. */
(function (root) {
  'use strict';
  function normalizeCommand(input, now = new Date()) {
    let s = String(input || '').trim().replace(/\s+/g, ' ');
    s = s.replace(/^(?:ol[aá][,.]?\s*)?(?:marapass[,.]?\s*)/i, '');
    s = s.replace(/^(?:por favor[, ]+|voc[eê] pode\s+|poderia\s+|eu gostaria de\s+|gostaria de\s+|eu quero\s+)/i, '');
    s = s.replace(/[, ]+por favor[.!?]*$/i, '');
    s = s.replace(/^(?:a gente|n[oó]s)\s+(?:vai|vamos|queremos ir)\s+(?:para|pra|pro|aos|a|[àá])\s+(?:(?:os|as)\s+)?/i, 'rota para ');
    s = s.replace(/^(?:n[aã]o[, ]+(?:eu\s+)?(?:disse|falei)|(?:eu\s+)?(?:disse|falei)|na verdade)[, ]+/i, 'localize ');
    s = s.replace(/^(?:me\s+)?(?:leva|leve|levem|leve-me|me leve|quero ir|quero chegar|ir|vou|vamos|bora)(?:\s+(?:para|pra|pro|at[eé]|[aà]))?\s+/i, 'rota para ');
    s = s.replace(/^(?:onde fica|onde [eé]|mostre onde fica|me mostre onde fica|me mostrar|me mostre|me mostra|mostra|ache|encontra|pesquise|pesquisa)\s+/i, 'localize ');
    s = s.replace(/\b(?:s[aã]o luiz|s[aã]o lu[ií]s do maranh[aã]o|slz)\b/gi, 'São Luís');
    s = s.replace(/\bolho\s+(?:d[’'´`]?\s*[aá]gua|dagua|dágua|de\s+[aá]gua)\b/gi, "Olho d'Água");
    // Legacy published search removes prepositions but matches contiguous text.
    // A distinctive substring yields real alternatives, never a silently chosen POI.
    s = s.replace(/\bpraia\s+(?:do\s+)?Olho d'Água/gi, "Olho d'Água");
    s = s.replace(/\bara(?:[cç]|ss|s)a(?:g|j)[iy]\b/gi, 'Araçagy');
    s = s.replace(/\b(?:desconto|descontos)\s+dispon[ií]veis\b/gi, 'descontos');
    // Existing Dart parser understands dates; avoid interpreting "depois de amanhã" as tomorrow.
    if (/\bdepois de amanh[aã](?![a-záã])/i.test(s)) {
      const parts = new Intl.DateTimeFormat('en-CA', {timeZone:'America/Fortaleza', year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now);
      const p = Object.fromEntries(parts.map(x => [x.type,x.value]));
      const d = new Date(Date.UTC(+p.year,+p.month-1,+p.day+2));
      s = s.replace(/\bdepois de amanh[aã](?![a-záã])/gi, `${d.getUTCDate()}/${d.getUTCMonth()+1}/${d.getUTCFullYear()}`);
    }
    return s.trim();
  }
  function list(items, extra = {}) {
    return Object.assign(items, extra, {item(i) { return this[i] ?? null; }});
  }
  function adaptResults(event) {
    const results = [];
    for (let i=0;i<event.results.length;i++) {
      const r = event.results.item ? event.results.item(i) : event.results[i];
      const first = r.item ? r.item(0) : r[0];
      // Preserve the recognizer's first choice: never silently select another destination.
      if (first?.transcript) results.push({transcript:first.transcript,confidence:first.confidence,isFinal:r.isFinal});
    }
    const text = normalizeCommand(results.map(r=>r.transcript).join(' '));
    const confidence = results.length ? results.reduce((n,r)=>n+(r.confidence||0),0)/results.length : 0;
    const alternatives = list([{transcript:text,confidence}], {isFinal:results.length>0 && results.every(r=>r.isFinal)});
    return {results:list(text ? [alternatives] : []), resultIndex:0};
  }
  function install(target) {
    const Native = target.SpeechRecognition || target.webkitSpeechRecognition;
    if (!Native || Native.maraPassAdapter) return false;
    function Recognition() {
      const native = new Native();
      let resultHandler=null, endHandler=null, errorHandler=null, silence=null, deadline=null;
      const clear = () => {target.clearTimeout(silence);target.clearTimeout(deadline);};
      native.onresult = event => {
        const adapted = adaptResults(event);
        target.clearTimeout(silence);
        // Bounded listening; paused speech is still allowed for five seconds.
        silence=target.setTimeout(()=>native.stop(),5000);
        if(adapted.results.length) resultHandler?.call(proxy,adapted);
      };
      native.onend = event => {clear();endHandler?.call(proxy,event);};
      native.onerror = event => {clear();errorHandler?.call(proxy,event);};
      const proxy = new Proxy(native, {
        get(object,key) {
          if(key==='onresult')return resultHandler;
          if(key==='onend')return endHandler;
          if(key==='onerror')return errorHandler;
          if(key==='start') return () => {
            clear();native.lang='pt-BR';native.maxAlternatives=3;
            native.start();deadline=target.setTimeout(()=>native.stop(),25000);
          };
          if(key==='stop'||key==='abort')return ()=>{clear();return native[key]();};
          const value=Reflect.get(object,key,object);
          return typeof value==='function'?value.bind(object):value;
        },
        set(object,key,value) {
          if(key==='onresult'){resultHandler=value;return true;}
          if(key==='onend'){endHandler=value;return true;}
          if(key==='onerror'){errorHandler=value;return true;}
          return Reflect.set(object,key,value,object);
        }
      });
      return proxy;
    }
    Recognition.prototype=Native.prototype;
    Recognition.maraPassAdapter=true;
    // speech_to_text's web implementation instantiates the prefixed constructor.
    target.SpeechRecognition=Recognition;
    target.webkitSpeechRecognition=Recognition;
    return true;
  }
  const api={normalizeCommand,adaptResults,install};
  if(typeof module!=='undefined' && module.exports)module.exports=api;
  if(root?.document)install(root);
})(typeof window==='undefined'?null:window);
