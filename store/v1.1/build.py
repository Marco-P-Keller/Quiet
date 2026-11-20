import json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from texts_a import T as A
from texts_b import T as B
T = {**A, **B}
LANG = {'en-US':'en','en-GB':'en','en-AU':'en','en-CA':'en','de-DE':'de','es-ES':'es','es-MX':'es',
 'fr-FR':'fr','fr-CA':'fr','pt-BR':'pt-BR','pt-PT':'pt-PT','it':'it','nl-NL':'nl','sv':'sv','da':'da',
 'no':'no','fi':'fi','pl':'pl','cs':'cs','sk':'sk','sl-SI':'sl','hr':'hr','hu':'hu','ro':'ro','el':'el',
 'ru':'ru','uk':'uk','tr':'tr','ca':'ca','id':'id','ms':'ms','vi':'vi','ar-SA':'ar','he':'he','ur-PK':'ur',
 'hi':'hi','bn-BD':'bn','gu-IN':'gu','kn-IN':'kn','ml-IN':'ml','mr-IN':'mr','or-IN':'or','pa-IN':'pa',
 'ta-IN':'ta','te-IN':'te','th':'th','ja':'ja','ko':'ko','zh-Hans':'zh-Hans','zh-Hant':'zh-Hant'}
out = {}; problems = []
for loc, lang in LANG.items():
    t = T[lang]
    paras = open(f'{loc}/description.txt').read().strip().split('\n\n')
    fb = [i for i,p in enumerate(paras) if p.startswith('•')]
    assert len(fb) == 4, loc
    paras[fb[3]] = t['bullet']
    paras.insert(fb[0]-1, t['feat'])
    desc = '\n\n'.join(paras)
    dropped = False
    if len(desc) > 4000:
        # The paragraph about the day turning at four is the one that can go:
        # the new paragraph and What's New both say "until four in the morning".
        idx = fb[3] + 1 + 3  # feat inserted: bullets shift by one; eight-things, way-out, day-turns
        del paras[idx]; desc = '\n\n'.join(paras); dropped = True
    name = open(f'{loc}/name.txt').read().strip()
    kw = t['kw']; sub = t['sub']
    for field, val, lim in [('desc',desc,4000),('sub',sub,30),('kw',kw,100),('new',t['new'],4000),('promo',t['promo'],170)]:
        if len(val) > lim: problems.append(f'{loc} {field} {len(val)}>{lim}')
    toks = set(re.findall(r'\w+', (name+' '+sub).lower()))
    dup = [w for w in kw.split(',') if w.lower() in toks]
    if dup: problems.append(f'{loc} kw duplicates {dup}')
    if ' ,' in kw or ', ' in kw: problems.append(f'{loc} kw spaces around comma')
    out[loc] = dict(description=desc, keywords=kw, subtitle=sub, whatsNew=t['new'], promotionalText=t['promo'], dropped=dropped)
    if '--write' in sys.argv:
        open(f'{loc}/description.txt','w').write(desc+'\n')
        open(f'{loc}/keywords.txt','w').write(kw+'\n')
        open(f'{loc}/subtitle.txt','w').write(sub+'\n')
        open(f'{loc}/whats-new.txt','w').write(t['new']+'\n')
        open(f'{loc}/promotional-text.txt','w').write(t['promo']+'\n')
json.dump(out, open('v1.1/listing.json','w'), ensure_ascii=False)
print('\n'.join(problems) or 'all within limits')
print('dropped the four-am paragraph in:', [l for l,v in out.items() if v['dropped']])
print('max desc', max(len(v['description']) for v in out.values()))
