import synth_port as sp
from synth_port import Voice, MAJOR, MINOR, PENTA, WHOLE

def V(preset, **kw):
    base = dict(fundamental=preset.fundamental, formant_scale=preset.formant_scale,
                tempo=preset.tempo, swing=preset.swing, scale=preset.scale, melody=preset.melody,
                vibrato_rate=preset.vibrato_rate, vibrato_depth=preset.vibrato_depth,
                breathiness=preset.breathiness, growl=preset.growl,
                declination=preset.declination, word_gap=preset.word_gap, brightness=preset.brightness)
    base.update(kw); return Voice(**base)

G,B,S,D,C,E = sp.GOOFBALL, sp.BRUISER, sp.SQUEAKER, sp.DIVA, sp.CHANTER, sp.EERIE

ROSTER = [
 ("tralalero","Tralalero Tralala","Tra-la-le-ro Tra-la-la","aquatic",  V(G,fundamental=128,tempo=3.6,melody=[0,2,4,2])),
 ("bombardiro","Bombardiro Crocodilo","Bom-bar-di-ro Cro-co-di-lo","aviator", V(B,fundamental=82,tempo=2.9,melody=[0,0,-3,0,2])),
 ("tungtung","Tung Tung Tung Sahur","Tung Tung Tung Sa-hur","oddity",  V(C,fundamental=146,tempo=2.2,melody=[0,0,0,1,0])),
 ("lirili","Lirilì Larilà","Li-ri-lì La-ri-là","flora",                V(E,fundamental=174,tempo=3.0,melody=[0,2,1,3,2,5])),
 ("patapim","Brr Brr Patapim","Brr Brr Pa-ta-pim","primate",           V(G,fundamental=110,tempo=4.0,growl=0.4,melody=[0,0,2,4,1])),
 ("chimpanzini","Chimpanzini Bananini","Chim-pan-zi-ni Ba-na-ni-ni","primate", V(S,fundamental=268,tempo=5.0,melody=[0,3,2,4,2])),
 ("ballerina","Ballerina Cappuccina","Bal-le-ri-na Cap-puc-ci-na","confection", V(D,fundamental=232,tempo=2.5,melody=[4,2,0,2,4,7])),
 ("cappuccino","Cappuccino Assassino","Cap-puc-ci-no As-sas-si-no","confection", V(C,fundamental=132,tempo=4.6,growl=0.42,melody=[0,1,0,-1])),
 ("trippi","Trippi Troppi","Trip-pi Trop-pi","aquatic",                V(S,fundamental=300,tempo=4.0,swing=0.5,melody=[4,0,5,2])),
 ("bobritto","Bobritto Bandito","Bo-brit-to Ban-di-to","oddity",       V(B,fundamental=96,tempo=3.3,growl=0.6,melody=[0,-2,0,3])),
 ("frigo","Frigo Camelo","Fri-go Ca-me-lo","oddity",                   V(G,fundamental=118,tempo=2.8,breathiness=0.3,melody=[2,0,-1,0])),
 ("boneca","Boneca Ambalabu","Bo-ne-ca Am-ba-la-bu","reptile",         V(E,fundamental=150,tempo=3.6,melody=[0,4,2,6,3])),
 ("vaca","La Vaca Saturno Saturnita","La Va-ca Sa-tur-no Sa-tur-ni-ta","bovine", V(D,fundamental=196,tempo=3.9,melody=[0,2,4,7,4,2])),
 ("glorbo","Glorbo Fruttodrillo","Glor-bo Frut-to-dril-lo","reptile",  V(B,fundamental=88,tempo=3.4,melody=[0,3,0,-2,0])),
 ("bombombini","Bombombini Gusini","Bom-bom-bi-ni Gu-si-ni","aviator", V(B,fundamental=104,tempo=4.4,growl=0.35,melody=[0,0,2,3,5])),
 ("trulimero","Trulimero Trulicina","Tru-li-me-ro Tru-li-ci-na","aquatic", V(G,fundamental=160,tempo=4.2,swing=0.4,melody=[2,4,5,4,2,0])),
 ("girafa","Girafa Celeste","Gi-ra-fa Ce-le-ste","oddity",             V(D,fundamental=210,tempo=2.6,vibrato_depth=0.7,melody=[7,4,2,0])),
 ("orangutini","Orangutini Ananassini","O-ran-gu-ti-ni A-na-nas-si-ni","primate", V(S,fundamental=240,tempo=5.4,melody=[0,2,3,5,7,5])),
 ("burbaloni","Burbaloni Luliloli","Bur-ba-lo-ni Lu-li-lo-li","flora", V(G,fundamental=142,tempo=3.9,swing=0.55,melody=[0,4,0,4,2])),
 ("blueberrini","Blueberrini Octopusini","Blu-ber-ri-ni Oc-to-pu-si-ni","aquatic", V(S,fundamental=284,tempo=4.8,melody=[5,3,2,0,2])),
 ("trictrac","Tric Trac Baraboom","Tric Trac Ba-ra-boom","oddity",     V(C,fundamental=120,tempo=3.2,growl=0.5,melody=[0,0,-2,-2,0])),
 ("zibra","Zibra Zubra Zibralini","Zi-bra Zu-bra Zi-bra-li-ni","bovine", V(E,fundamental=165,tempo=4.5,melody=[0,1,2,3,4,5])),
 ("piccione","Piccione Macchina","Pic-cio-ne Mac-chi-na","aviator",    V(C,fundamental=155,tempo=3.5,brightness=0.75,melody=[0,2,0,2])),
 ("svinino","Svinino Bombondino","Svi-ni-no Bom-bon-di-no","aviator",  V(B,fundamental=92,tempo=3.7,breathiness=0.25,melody=[0,2,0,-3,0])),
]
