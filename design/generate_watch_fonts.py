from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root=Path(__file__).resolve().parents[1]
fonts=root/'design/fonts/Barlow_Condensed'
out=root/'resources/fonts'
out.mkdir(parents=True,exist_ok=True)
variants=[('RepNumber','SemiBold',160,'0123456789'),('RepTimer','Medium',64,'0123456789:'),('RepLabel','Medium',28,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 +/:'),('RepFooter','Medium',22,'0123456789+/ sABCDEFGHIJKLMNOPQRSTUVWXYZ')]
for name,weight,size,chars in variants:
    font=ImageFont.truetype(str(fonts/f'BarlowCondensed-{weight}.ttf'),size)
    boxes={c:font.getbbox(c) for c in chars}
    top=min(b[1] for c,b in boxes.items() if c!=' ')
    bottom=max(b[3] for b in boxes.values())
    height=bottom-top
    atlas=Image.new('RGBA',(512,512),(255,255,255,0)); draw=ImageDraw.Draw(atlas)
    x=y=1; rows=[]; rowheight=0
    for c in chars:
        l,t,r,b=boxes[c]; w=max(1,r-l); h=max(1,b-t)
        if x+w+1>512: x=1; y+=rowheight+2; rowheight=0
        draw.text((x-l,y-t),c,font=font,fill=(255,255,255,255))
        rows.append(f'char id={ord(c)} x={x} y={y} width={w} height={h} xoffset={l} yoffset={max(0,t-top)} xadvance={round(font.getlength(c))} page=0 chnl=15')
        x+=w+2; rowheight=max(rowheight,h)
    used=y+rowheight+1
    atlas.crop((0,0,512,used)).save(out/f'{name}.png')
    header=[f'info face="Barlow Condensed {weight}" size={size} bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1',f'common lineHeight={height} base={height} scaleW=512 scaleH={used} pages=1 packed=0',f'page id=0 file="{name}.png"',f'chars count={len(chars)}']
    (out/f'{name}.fnt').write_text('\n'.join(header+rows)+'\n')
(out/'fonts.xml').write_text('<resources>\n'+''.join(f'  <font id="{name}" filename="{name}.fnt" antialias="true" />\n' for name,*_ in variants)+'</resources>\n')
print('Generated three bitmap font sizes')
