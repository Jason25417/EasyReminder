from PIL import Image, ImageDraw, ImageFilter

SS = 4                      # 超采样倍数
S  = 1024 * SS
def px(v): return int(v * SS)

# ---------- 满幅方形主画（iOS 用，也是 mac 版素材） ----------
img = Image.new("RGB", (S, S))
p = img.load()
top, bot = (111,182,255), (33,84,199)      # 上浅下深品牌蓝
for y in range(S):
    t = y/(S-1)
    r = round(top[0]+(bot[0]-top[0])*t); g = round(top[1]+(bot[1]-top[1])*t); b = round(top[2]+(bot[2]-top[2])*t)
    for x in range(0, S, 1):
        p[x, y] = (r, g, b)

# 左上柔光
glow = Image.new("RGBA", (S, S), (0,0,0,0))
gd = ImageDraw.Draw(glow)
gd.ellipse((px(-260), px(-320), px(720), px(420)), fill=(255,255,255,52))
glow = glow.filter(ImageFilter.GaussianBlur(px(90)))
img = Image.alpha_composite(img.convert("RGBA"), glow)

# 卡片阴影
CARD = (px(268), px(240), px(756), px(800)); R = px(58)
sh = Image.new("RGBA", (S, S), (0,0,0,0))
sd = ImageDraw.Draw(sh)
sd.rounded_rectangle((CARD[0], CARD[1]+px(26), CARD[2], CARD[3]+px(26)), radius=R, fill=(8,28,80,110))
sh = sh.filter(ImageFilter.GaussianBlur(px(34)))
img = Image.alpha_composite(img, sh)

d = ImageDraw.Draw(img)
# 白卡片（日历页）
d.rounded_rectangle(CARD, radius=R, fill=(255,255,255,255))
# 日历头（顶部圆角、底部平直）
HEADER_BOT = px(408)
d.rounded_rectangle((CARD[0], CARD[1], CARD[2], HEADER_BOT + R), radius=R, fill=(61,123,232,255))
d.rectangle((CARD[0], HEADER_BOT, CARD[2], HEADER_BOT + R), fill=(255,255,255,255))
d.rectangle((CARD[0], px(340), CARD[2], HEADER_BOT), fill=(61,123,232,255))
# 头上两个装订孔
for cx in (px(400), px(624)):
    d.ellipse((cx-px(26), px(300)-px(26), cx+px(26), px(300)+px(26)), fill=(255,255,255,255))
    d.ellipse((cx-px(14), px(300)-px(14), cx+px(14), px(300)+px(14)), fill=(61,123,232,255))

# 蓝对勾（品牌延续）
pts = [(px(398), px(596)), (px(486), px(684)), (px(642), px(492))]
w = px(62); r2 = w//2
d.line(pts, fill=(45,107,224,255), width=w, joint="curve")
for (cx, cy) in pts:
    d.ellipse((cx-r2, cy-r2, cx+r2, cy+r2), fill=(45,107,224,255))

full = img.convert("RGB").resize((1024, 1024), Image.LANCZOS)
full.save("ios_1024.png", "PNG")

# ---------- mac 版：内容缩进 squircle + 透明边距 + 投影 ----------
mac = Image.new("RGBA", (1024, 1024), (0,0,0,0))
inner = 824
art = img.resize((inner*2, inner*2), Image.LANCZOS)   # 2x 中间量抗锯齿
mask = Image.new("L", (inner*2, inner*2), 0)
ImageDraw.Draw(mask).rounded_rectangle((0,0,inner*2,inner*2), radius=int(inner*2*0.225), fill=255)
art.putalpha(mask)
art = art.resize((inner, inner), Image.LANCZOS)
sh2 = Image.new("RGBA", (1024,1024), (0,0,0,0))
ImageDraw.Draw(sh2).rounded_rectangle((100, 112, 100+inner, 112+inner), radius=int(inner*0.225), fill=(20,50,120,120))
sh2 = sh2.filter(ImageFilter.GaussianBlur(18))
mac = Image.alpha_composite(mac, sh2)
mac.paste(art, (100, 96), art)
mac.save("mac_1024.png", "PNG")
print("done: ios_1024.png / mac_1024.png")
