import pathlib
from PIL import Image,ImageOps
d=pathlib.Path(__file__).parent
src=d.parent/'outgold-sites/company/logo-original.jpg'
im=Image.open(src).convert('RGB')
im.save(d/'logo-original.jpg',quality=92)
for size in (192,512):
    out=Image.new('RGB',(size,size),'#080808')
    logo=ImageOps.contain(im,(size,size))
    out.paste(logo,((size-logo.width)//2,(size-logo.height)//2))
    out.save(d/f'icon-{size}.png')
