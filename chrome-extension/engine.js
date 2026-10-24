(function(root){
 'use strict';
 const words=['ありがとう','ありがとうございます','感謝','嬉しい','うれしい','楽しい','たのしい','最高','大好き','好き','おめでとう','頑張った','がんばった','素晴らしい','すごい','幸せ','助かった','よかった','いいね','応援してる','大丈夫','できた'].sort((a,b)=>b.length-a.length||a.localeCompare(b));
 const negative=['じゃない','ではない','でない','くない','しくない','とは思わない','と思わない','と言えな','って言えな','といえな','とは言えな','ではなかった','じゃなかった','くなかった','しくなかった','ない','なかった'];
 function analyze(text){let remaining=String(text).normalize('NFKC'),found=[];for(const word of words){let from=0,match=false;while(from<remaining.length){let i=remaining.indexOf(word,from);if(i<0)break;if(!negative.some(n=>remaining.slice(i+word.length).startsWith(n)))match=true;from=i+word.length}if(match){found.push(word);remaining=remaining.split(word).join('\uFFFC')}}return found}
 function eligible({tag,type='',autocomplete='',hint='',privateField=false}){if(privateField||!['TEXTAREA','INPUT','CONTENTEDITABLE'].includes(tag))return false;if(tag==='INPUT'&&!['','text'].includes(type.toLowerCase()))return false;if(/(?:password|passcode|credit.?card|card.?number|security.?code|cvv|cvc|one.?time|verification|パスワード|暗証|カード番号|認証コード)/i.test(hint))return false;return !/(?:password|one-time-code|cc-|email|tel|address|name|bday|transaction)/i.test(autocomplete)}
 function validRequest(id){return typeof id==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)}
 const api={analyze,eligible,validRequest};root.PFEngine=api;if(typeof module!=='undefined')module.exports=api;
})(globalThis);
