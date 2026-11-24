import os,json,re
from flask import Flask,request,jsonify,Response
import redis
app=Flask(__name__)
app.config['MAX_CONTENT_LENGTH']=8192
db=redis.from_url(os.environ['REDIS_URL'],decode_responses=True,socket_connect_timeout=5,socket_timeout=5)
groups=[["🍖 Carnes e pratos principais",["Lombo suíno","Frango assado","Carne assada","Costelinha assada","Coxa e sobrecoxa","Linguiça assada","Peru","Chester"]],["🍚 Acompanhamentos",["Arroz à grega","Arroz branco","Macarronada","Maionese","Salada de macarrão","Farofa","Batatas gratinadas","Salpicão"]],["🧀 Entradas e complementos",["Tábua de frios","Pães"]],["🍮 Sobremesas",["Bombom na travessa","Pavê","Gelatina colorida","Bolo","Sorvete","Abacaxi gelado","Pudim","Salada de frutas"]],["🥤 Bebidas",["Refrigerantes","Sucos"]]]
valid={str(i)+'-'+str(j) for i,g in enumerate(groups) for j in range(len(g[1]))}
key='ceia:2026:ballots'
def tally():
    votes=db.hvals(key)
    counts={v:0 for v in valid}
    for ballot in votes:
        for v in json.loads(ballot):
            if v in counts: counts[v]+=1
    return {'total':len(votes),'counts':counts}
@app.errorhandler(redis.RedisError)
def unavailable(e):
    return jsonify(error='Servidor de votos temporariamente indisponível. Tente novamente.'),503
@app.get('/api/health')
def health():
    return jsonify(ok=bool(db.ping()))
@app.get('/api/results')
def results():
    return jsonify(tally())
@app.post('/api/vote')
def vote():
    data=request.get_json(silent=True) or {}
    token=data.get('token','')
    picks=data.get('picks',[])
    if not isinstance(token,str) or not re.fullmatch(r'[a-f0-9]{32}',token) or not isinstance(picks,list) or not picks or len(picks)>len(valid) or any(not isinstance(x,str) or x not in valid for x in picks):
        return jsonify(error='Selecione opções válidas.'),400
    db.hset(key,token,json.dumps(sorted(set(picks))))
    return jsonify(tally())
@app.after_request
def headers(res):
    res.headers['Cache-Control']='no-store'
    res.headers['X-Content-Type-Options']='nosniff'
    return res
@app.get('/')
def home():
    return Response(PAGE.replace('__GROUPS__',json.dumps(groups,ensure_ascii=False)),mimetype='text/html')
PAGE=r"""<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="Escolha seus pratos favoritos para a ceia de Natal. Votação coletiva."><title>Ceia de Natal 2026 • Votação</title><style>
*{box-sizing:border-box}body{margin:0;font:16px system-ui;color:#fff4db;background:radial-gradient(ellipse at top,#315c43,#091d16 55%);min-height:100vh}main{max-width:820px;margin:auto;padding:14px 14px 115px}header{text-align:center;padding:28px 15px;background:radial-gradient(ellipse at top,#ad3940,#511019 70%);border:2px solid #d6a65c;border-radius:25px;box-shadow:0 12px 32px #0009,inset 0 1px 4px #ffd998}header .decor{font-size:40px;letter-spacing:7px}h1{font:bold clamp(30px,6vw,48px) Georgia;color:#ffe0a1;margin:10px 0;text-shadow:0 3px 4px #0009}header p{margin:8px 0;line-height:1.5}.tabs{display:flex;gap:8px;margin:16px 0}.tabs button{flex:1}.panel{margin:12px 0;padding:16px;background:linear-gradient(145deg,#294b37,#14291e);border:1px solid #b48b49;border-radius:19px;box-shadow:0 8px 20px #0006,inset 0 1px 1px #ffffff33}h2{font:bold 21px Georgia;color:#ffe1a0;margin:0 0 14px}.options{display:grid;grid-template-columns:repeat(auto-fit,minmax(145px,1fr));gap:9px}.opt{display:flex;align-items:center;gap:9px;min-height:55px;padding:10px;background:#0e271c;border:1px solid #859478;border-radius:12px;cursor:pointer}.opt:has(input:checked){background:#654820;border-color:#ffd581;box-shadow:0 0 12px #e3bc4c55}input{accent-color:#e5b658;width:21px;height:21px;flex-shrink:0}button{font:700 15px system-ui;cursor:pointer;border:1px solid #d4ac62;border-radius:13px;padding:13px 16px;background:#203e2c;color:#ffe4a1}button.active,button.primary{background:linear-gradient(#ffe5a8,#c48e33);color:#261709;box-shadow:0 4px 14px #0007}button:disabled{opacity:.55;cursor:default}.bottom{position:fixed;bottom:0;left:0;right:0;padding:12px 14px max(12px,env(safe-area-inset-bottom));background:#0a1d16f5;border-top:1px solid #a9844c;text-align:center;z-index:5}.bottom button{width:100%;max-width:790px}.small{font-size:13px;color:#dfd1ae;text-align:center}.stat{text-align:center;background:#1c3828;border:1px solid #b58b48;padding:12px;border-radius:14px}.stat strong{font-size:30px;color:#ffe2a0}footer{text-align:center;color:#d1ad6a;padding:18px;font-size:12px}.rank{margin:12px 0}.line{display:flex;justify-content:space-between;gap:8px;font-size:14px}.bar{height:8px;background:#0b2218;border-radius:8px;overflow:hidden;margin-top:5px}.bar span{display:block;height:100%;background:linear-gradient(90deg,#b48a3c,#ffe2a0);border-radius:8px}#notice{text-align:center;margin:10px 0;color:#ffdf99;min-height:22px}#result[hidden],#voting[hidden],#bottom[hidden]{display:none}.tag{font-size:12px;letter-spacing:2px;text-transform:uppercase;color:#f8d58c}
</style></head><body><main><header><div class="decor">🎄 ✨ 🎁</div><div class="tag">Enquete oficial • 2026</div><h1>Nossa ceia de Natal</h1><p>Escolha seus pratos favoritos e ajude a montar uma ceia inesquecível.</p><div class="small">Votação coletiva • Escolha quantas opções quiser</div></header><div class="tabs"><button id="vt" class="active" onclick="tab(false)">🗳️ Votar</button><button id="rt" onclick="tab(true)">🏆 Resultados</button></div><div class="stat"><strong id="total">—</strong><div class="small">participantes na votação</div></div><div id="notice" role="status"></div><section id="voting"></section><section id="result" hidden></section><footer>Tecnologia OutGold</footer></main><div class="bottom" id="bottom"><div class="small" id="selected">0 opções selecionadas</div><button class="primary" id="submit" onclick="submitVote()">Confirmar meu voto</button></div><script>
const groups=__GROUPS__;let picks=new Set(),token,stored=false;const el=id=>document.getElementById(id);
try{token=localStorage.getItem('ceia26-token');if(!token){token=Array.from(crypto.getRandomValues(new Uint8Array(16)),x=>x.toString(16).padStart(2,'0')).join('');localStorage.setItem('ceia26-token',token)}picks=new Set(JSON.parse(localStorage.getItem('ceia26-picks')||'[]'));stored=localStorage.getItem('ceia26-saved')==='1'}catch(e){token=Array.from(crypto.getRandomValues(new Uint8Array(16)),x=>x.toString(16).padStart(2,'0')).join('')}
function update(){el('selected').textContent=picks.size+' opções selecionadas';el('submit').disabled=!picks.size;el('submit').textContent=stored?'Atualizar meu voto':'Confirmar meu voto'}
groups.forEach((g,i)=>{let panel=document.createElement('div');panel.className='panel';let title=document.createElement('h2');title.textContent=g[0];panel.append(title);let opts=document.createElement('div');opts.className='options';g[1].forEach((name,j)=>{let id=i+'-'+j,label=document.createElement('label');label.className='opt';let cb=document.createElement('input');cb.type='checkbox';cb.checked=picks.has(id);cb.onchange=()=>{cb.checked?picks.add(id):picks.delete(id);update()};label.append(cb,document.createTextNode(name));opts.append(label)});panel.append(opts);el('voting').append(panel)});update();
function draw(data){el('total').textContent=data.total;el('result').replaceChildren();groups.forEach((g,i)=>{let panel=document.createElement('div');panel.className='panel';let title=document.createElement('h2');title.textContent=g[0];panel.append(title);g[1].map((n,j)=>({n,c:data.counts[i+'-'+j]||0})).sort((a,b)=>b.c-a.c).forEach((x,j)=>{let pct=data.total?Math.round(x.c*100/data.total):0;let row=document.createElement('div');row.className='rank';let line=document.createElement('div');line.className='line';let a=document.createElement('span');a.textContent=(j===0&&x.c>0?'🏆 ':'')+x.n;let b=document.createElement('span');b.textContent=x.c+' voto(s) • '+pct+'%';line.append(a,b);let bar=document.createElement('div');bar.className='bar';let fill=document.createElement('span');fill.style.width=pct+'%';bar.append(fill);row.append(line,bar);panel.append(row)});el('result').append(panel)})}
async function refresh(){try{let r=await fetch('/api/results',{cache:'no-store'});if(!r.ok)throw Error();draw(await r.json())}catch(e){el('notice').textContent='Não foi possível atualizar os resultados. Tentando novamente.'}}
function tab(result){el('voting').hidden=result;el('result').hidden=!result;el('bottom').hidden=result;el('vt').classList.toggle('active',!result);el('rt').classList.toggle('active',result);if(result)refresh()}
async function submitVote(){if(!picks.size)return;el('submit').disabled=true;el('submit').textContent='Enviando…';try{let r=await fetch('/api/vote',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token,picks:[...picks]})});let d=await r.json();if(!r.ok)throw Error(d.error||'Falha no envio');stored=true;try{localStorage.setItem('ceia26-picks',JSON.stringify([...picks]));localStorage.setItem('ceia26-saved','1')}catch(e){}draw(d);el('notice').textContent='✓ Seu voto foi registrado!';tab(true)}catch(e){el('notice').textContent=e.message||'Erro ao enviar. Tente novamente.'}finally{update()}}
refresh();setInterval(refresh,15000);
</script></body></html>"""
if __name__=='__main__':
    app.run(host='0.0.0.0',port=int(os.environ.get('PORT','10000')))
