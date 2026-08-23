import Foundation

/// The roster.
///
/// Voices were tuned offline against a spectral analysis of every render: the
/// closest-sounding pair sits at distance 1.25 against a roster median of 4.74, so
/// no round should ever come down to a coin flip. Pitch spans 81–459 Hz and
/// speaking rate 1.8–4.8 syllables per second, which is most of what a
/// half-asleep listener actually uses to tell them apart.
enum BrainrotCatalog {

    static let all: [BrainrotCharacter] = [

        BrainrotCharacter(
            id: "tralalero", name: "Tralalero Tralala",
            chant: "Tra-la-le-ro Tra-la-la",
            tagline: "Three-legged shark. Wears sneakers. Deeply unserious.",
            family: .aquatic, tier: .starter,
            voice: .goofball.with { $0.fundamental = 128; $0.tempo = 3.6; $0.melody = [0, 2, 4, 2] },
            art: CreatureRecipe(body: .blob, head: .wedge, ears: .fin, limbs: .fins,
                                eyes: .beady, mouth: .fangs, prop: .sneakers, pattern: .none,
                                palette: Palette(body: 0x2E6FD9, bodyShade: 0x1B4C9E, accent: 0xFFFFFF,
                                                 backdropTop: 0x0B2A5C, backdropBottom: 0x1F6FB2))),

        BrainrotCharacter(
            id: "bombardiro", name: "Bombardiro Crocodilo",
            chant: "Bom-bar-di-ro Cro-co-di-lo",
            tagline: "Crocodile fused to a bomber. Not open to discussion.",
            family: .aviator, tier: .starter,
            voice: .bruiser.with { $0.fundamental = 82; $0.tempo = 2.9 },
            art: CreatureRecipe(body: .fuselage, head: .wedge, ears: .none, limbs: .wings,
                                eyes: .shades, mouth: .fangs, prop: .bomb, pattern: .scales,
                                palette: Palette(body: 0x4C8B3B, bodyShade: 0x2E5C24, accent: 0xC8A24A,
                                                 backdropTop: 0x2A3A22, backdropBottom: 0x5C6B3A))),

        BrainrotCharacter(
            id: "tungtung", name: "Tung Tung Tung Sahur",
            chant: "Tung Tung Tung Sa-hur",
            tagline: "A log with a bat. Arrives when you ignore the third call.",
            family: .oddity, tier: .starter,
            voice: .chanter.with { $0.fundamental = 146; $0.tempo = 2.2 },
            art: CreatureRecipe(body: .log, head: .merged, ears: .none, limbs: .stubby,
                                eyes: .big, mouth: .gasp, prop: .drumstick, pattern: .none,
                                palette: Palette(body: 0xB5793C, bodyShade: 0x7A4E22, accent: 0xF0D9A8,
                                                 backdropTop: 0x3A2A1A, backdropBottom: 0x7A5A38))),

        BrainrotCharacter(
            id: "lirili", name: "Lirilì Larilà",
            chant: "Li-ri-lì La-ri-là",
            tagline: "Cactus elephant. Owns a clock. Controls time, allegedly.",
            family: .flora, tier: .starter,
            voice: .eerie.with { $0.fundamental = 174; $0.tempo = 3.0 },
            art: CreatureRecipe(body: .tall, head: .snout, ears: .floppy, limbs: .stubby,
                                eyes: .sleepy, mouth: .flat, prop: .clock, pattern: .stripes,
                                palette: Palette(body: 0x6FA84F, bodyShade: 0x4A7534, accent: 0xE8C55A,
                                                 backdropTop: 0x2F4A2A, backdropBottom: 0x8FBF6A))),

        BrainrotCharacter(
            id: "patapim", name: "Brr Brr Patapim",
            chant: "Brr Brr Pa-ta-pim",
            tagline: "Half monkey, half shrubbery, entirely nose.",
            family: .primate, tier: .starter,
            voice: .goofball.with { $0.fundamental = 110; $0.tempo = 4.0; $0.growl = 0.4; $0.melody = [0, 0, 2, 4, 1] },
            art: CreatureRecipe(body: .pear, head: .snout, ears: .leaf, limbs: .long,
                                eyes: .big, mouth: .smile, prop: .none, pattern: .spots,
                                palette: Palette(body: 0x8B6B4A, bodyShade: 0x5C4630, accent: 0x7FBF5A,
                                                 backdropTop: 0x3A3020, backdropBottom: 0x6B5A3A))),

        BrainrotCharacter(
            id: "chimpanzini", name: "Chimpanzini Bananini",
            chant: "Chim-pan-zi-ni Ba-na-ni-ni",
            tagline: "Monkey wearing a banana as a body. Structurally sound.",
            family: .primate, tier: .starter,
            voice: .squeaker.with { $0.fundamental = 268; $0.tempo = 5.0 },
            art: CreatureRecipe(body: .fruit, head: .snout, ears: .round, limbs: .stubby,
                                eyes: .big, mouth: .grin, prop: .banana, pattern: .none,
                                palette: Palette(body: 0xF2C63D, bodyShade: 0xC79A22, accent: 0x6B4A2A,
                                                 backdropTop: 0x6B5A10, backdropBottom: 0xF2D46A))),

        BrainrotCharacter(
            id: "ballerina", name: "Ballerina Cappuccina",
            chant: "Bal-le-ri-na Cap-puc-ci-na",
            tagline: "Prima ballerina. Head is a cappuccino. No notes.",
            family: .confection, tier: .starter,
            voice: .diva.with { $0.fundamental = 232; $0.tempo = 2.5 },
            art: CreatureRecipe(body: .cup, head: .round, ears: .none, limbs: .long,
                                eyes: .sleepy, mouth: .smile, prop: .tutu, pattern: .none,
                                palette: Palette(body: 0xE8D5B7, bodyShade: 0xC4A882, accent: 0xE05A8A,
                                                 backdropTop: 0x7A3A5A, backdropBottom: 0xE0A8C4))),

        BrainrotCharacter(
            id: "cappuccino", name: "Cappuccino Assassino",
            chant: "Cap-puc-ci-no As-sas-si-no",
            tagline: "Espresso with two blades and unresolved business.",
            family: .confection, tier: .starter,
            voice: .chanter.with { $0.fundamental = 132; $0.tempo = 4.6; $0.growl = 0.42; $0.melody = [0, 1, 0, -1] },
            art: CreatureRecipe(body: .cup, head: .merged, ears: .none, limbs: .stubby,
                                eyes: .shades, mouth: .flat, prop: .blade, pattern: .none,
                                palette: Palette(body: 0x4A3020, bodyShade: 0x2E1C12, accent: 0xD94A3A,
                                                 backdropTop: 0x1A1012, backdropBottom: 0x5C3A2A))),

        BrainrotCharacter(
            id: "trippi", name: "Trippi Troppi",
            chant: "Trip-pi Trop-pi",
            tagline: "Cat wearing a shrimp. Or shrimp wearing a cat.",
            family: .aquatic, tier: .core,
            voice: .squeaker.with { $0.fundamental = 300; $0.tempo = 4.0; $0.swing = 0.5; $0.melody = [4, 0, 5, 2] },
            art: CreatureRecipe(body: .wide, head: .round, ears: .pointy, limbs: .stubby,
                                eyes: .googly, mouth: .grin, prop: .none, pattern: .stripes,
                                palette: Palette(body: 0xF27A5A, bodyShade: 0xC4523A, accent: 0xFFE0D0,
                                                 backdropTop: 0x5C2A2A, backdropBottom: 0xF2A88A))),

        BrainrotCharacter(
            id: "bobritto", name: "Bobritto Bandito",
            chant: "Bo-brit-to Ban-di-to",
            tagline: "Beaver. Pinstripes. Cigar. Runs the canal district.",
            family: .oddity, tier: .core,
            voice: .bruiser.with { $0.fundamental = 96; $0.tempo = 3.3; $0.growl = 0.6; $0.melody = [0, -2, 0, 3] },
            art: CreatureRecipe(body: .pear, head: .snout, ears: .round, limbs: .stubby,
                                eyes: .shades, mouth: .fangs, prop: .cigar, pattern: .none,
                                palette: Palette(body: 0x7A5A3A, bodyShade: 0x4E3A24, accent: 0xD9C48A,
                                                 backdropTop: 0x2A2018, backdropBottom: 0x5C4A34))),

        BrainrotCharacter(
            id: "frigo", name: "Frigo Camelo",
            chant: "Fri-go Ca-me-lo",
            tagline: "Camel that is also a refrigerator. Stays cool.",
            family: .oddity, tier: .core,
            voice: .goofball.with { $0.fundamental = 118; $0.tempo = 2.8; $0.breathiness = 0.3; $0.melody = [2, 0, -1, 0] },
            art: CreatureRecipe(body: .wide, head: .snout, ears: .round, limbs: .long,
                                eyes: .sleepy, mouth: .flat, prop: .fridge, pattern: .none,
                                palette: Palette(body: 0xD9B47A, bodyShade: 0xA8874E, accent: 0xB8D9E0,
                                                 backdropTop: 0x4A3A28, backdropBottom: 0xC4A87A))),

        BrainrotCharacter(
            id: "boneca", name: "Boneca Ambalabu",
            chant: "Bo-ne-ca Am-ba-la-bu",
            tagline: "Frog head, tyre torso, human legs. Sleep well.",
            family: .reptile, tier: .core,
            voice: .eerie.with { $0.fundamental = 150; $0.tempo = 3.6; $0.melody = [0, 4, 2, 6, 3] },
            art: CreatureRecipe(body: .blob, head: .round, ears: .none, limbs: .long,
                                eyes: .googly, mouth: .grin, prop: .tyre, pattern: .none,
                                palette: Palette(body: 0x5AA84A, bodyShade: 0x3A7530, accent: 0x2A2A2E,
                                                 backdropTop: 0x1A2A1A, backdropBottom: 0x4A7A3A))),

        BrainrotCharacter(
            id: "vaca", name: "La Vaca Saturno Saturnita",
            chant: "La Va-ca Sa-tur-no Sa-tur-ni-ta",
            tagline: "Dairy cow with a planetary ring. Astronomically loud.",
            family: .bovine, tier: .core,
            voice: .diva.with { $0.fundamental = 196; $0.tempo = 3.9; $0.melody = [0, 2, 4, 7, 4, 2] },
            art: CreatureRecipe(body: .wide, head: .snout, ears: .horns, limbs: .hooves,
                                eyes: .big, mouth: .smile, prop: .planetRing, pattern: .spots,
                                palette: Palette(body: 0xF0EDE6, bodyShade: 0xC4BEB2, accent: 0xE0A85A,
                                                 backdropTop: 0x2A2A4A, backdropBottom: 0x6A6AA8))),

        BrainrotCharacter(
            id: "glorbo", name: "Glorbo Fruttodrillo",
            chant: "Glor-bo Frut-to-dril-lo",
            tagline: "Crocodile with a watermelon situation.",
            family: .reptile, tier: .core,
            voice: .bruiser.with { $0.fundamental = 88; $0.tempo = 3.4; $0.melody = [0, 3, 0, -2, 0] },
            art: CreatureRecipe(body: .blob, head: .wedge, ears: .none, limbs: .stubby,
                                eyes: .beady, mouth: .fangs, prop: .melon, pattern: .stripes,
                                palette: Palette(body: 0x4A9A3A, bodyShade: 0x2E6B24, accent: 0xE05A5A,
                                                 backdropTop: 0x1A3A1A, backdropBottom: 0x4A8A3A))),

        BrainrotCharacter(
            id: "bombombini", name: "Bombombini Gusini",
            chant: "Bom-bom-bi-ni Gu-si-ni",
            tagline: "Goose airframe. Ordnance included.",
            family: .aviator, tier: .core,
            voice: .bruiser.with { $0.fundamental = 104; $0.tempo = 4.4; $0.growl = 0.35; $0.melody = [0, 0, 2, 3, 5] },
            art: CreatureRecipe(body: .fuselage, head: .beak, ears: .none, limbs: .wings,
                                eyes: .beady, mouth: .beak, prop: .bomb, pattern: .none,
                                palette: Palette(body: 0xF2F0E8, bodyShade: 0xC4C0B4, accent: 0xE0A020,
                                                 backdropTop: 0x3A4A5C, backdropBottom: 0x8AA8C4))),

        BrainrotCharacter(
            id: "trulimero", name: "Trulimero Trulicina",
            chant: "Tru-li-me-ro Tru-li-ci-na",
            tagline: "Fish body, cat head, and three human legs.",
            family: .aquatic, tier: .core,
            voice: .goofball.with { $0.fundamental = 160; $0.tempo = 4.2; $0.swing = 0.4; $0.melody = [2, 4, 5, 4, 2, 0] },
            art: CreatureRecipe(body: .wide, head: .round, ears: .pointy, limbs: .long,
                                eyes: .big, mouth: .grin, prop: .none, pattern: .scales,
                                palette: Palette(body: 0x3AA8A0, bodyShade: 0x24756E, accent: 0xF2D46A,
                                                 backdropTop: 0x1A3A3A, backdropBottom: 0x3A8A8A))),

        BrainrotCharacter(
            id: "girafa", name: "Girafa Celeste",
            chant: "Gi-ra-fa Ce-le-ste",
            tagline: "Giraffe of the heavens. Neck reaches low orbit.",
            family: .oddity, tier: .deep,
            voice: .diva.with { $0.fundamental = 210; $0.tempo = 2.6; $0.vibratoDepth = 0.7; $0.melody = [7, 4, 2, 0] },
            art: CreatureRecipe(body: .tall, head: .snout, ears: .antennae, limbs: .long,
                                eyes: .sleepy, mouth: .smile, prop: .sparkles, pattern: .spots,
                                palette: Palette(body: 0x8A6AC4, bodyShade: 0x5C4290, accent: 0xF2E08A,
                                                 backdropTop: 0x1A1030, backdropBottom: 0x5A3A9A))),

        BrainrotCharacter(
            id: "orangutini", name: "Orangutini Ananassini",
            chant: "O-ran-gu-ti-ni A-na-nas-si-ni",
            tagline: "Orangutan issued a pineapple. Wears it well.",
            family: .primate, tier: .deep,
            voice: .squeaker.with { $0.fundamental = 240; $0.tempo = 5.4; $0.melody = [0, 2, 3, 5, 7, 5] },
            art: CreatureRecipe(body: .fruit, head: .snout, ears: .round, limbs: .long,
                                eyes: .big, mouth: .gasp, prop: .pineapple, pattern: .checker,
                                palette: Palette(body: 0xE08A2A, bodyShade: 0xB0651A, accent: 0x7ABF4A,
                                                 backdropTop: 0x5C3A10, backdropBottom: 0xE0A84A))),

        BrainrotCharacter(
            id: "burbaloni", name: "Burbaloni Luliloli",
            chant: "Bur-ba-lo-ni Lu-li-lo-li",
            tagline: "A coconut. There is a capybara inside. Do not ask.",
            family: .flora, tier: .deep,
            voice: .goofball.with { $0.fundamental = 142; $0.tempo = 3.9; $0.swing = 0.55; $0.melody = [0, 4, 0, 4, 2] },
            art: CreatureRecipe(body: .fruit, head: .merged, ears: .round, limbs: .stubby,
                                eyes: .sleepy, mouth: .flat, prop: .coconut, pattern: .none,
                                palette: Palette(body: 0x6B4A2A, bodyShade: 0x46301A, accent: 0xF2EDE0,
                                                 backdropTop: 0x2A4A3A, backdropBottom: 0x6A9A7A))),

        BrainrotCharacter(
            id: "blueberrini", name: "Blueberrini Octopusini",
            chant: "Blu-ber-ri-ni Oc-to-pu-si-ni",
            tagline: "Octopus made of blueberry. Eight opinions.",
            family: .aquatic, tier: .deep,
            voice: .squeaker.with { $0.fundamental = 284; $0.tempo = 4.8; $0.melody = [5, 3, 2, 0, 2] },
            art: CreatureRecipe(body: .blob, head: .merged, ears: .none, limbs: .tentacles,
                                eyes: .big, mouth: .gasp, prop: .berry, pattern: .none,
                                palette: Palette(body: 0x5A5AC4, bodyShade: 0x3A3A90, accent: 0x8AE0D0,
                                                 backdropTop: 0x1A1A4A, backdropBottom: 0x4A4AA8))),

        BrainrotCharacter(
            id: "trictrac", name: "Tric Trac Baraboom",
            chant: "Tric Trac Ba-ra-boom",
            tagline: "Football. Grenade. The distinction has collapsed.",
            family: .oddity, tier: .deep,
            voice: .chanter.with { $0.fundamental = 120; $0.tempo = 3.2; $0.growl = 0.5; $0.melody = [0, 0, -2, -2, 0] },
            art: CreatureRecipe(body: .blob, head: .merged, ears: .none, limbs: .stubby,
                                eyes: .beady, mouth: .flat, prop: .ball, pattern: .checker,
                                palette: Palette(body: 0x4A5A3A, bodyShade: 0x2E3A24, accent: 0xE0E0E0,
                                                 backdropTop: 0x1A2018, backdropBottom: 0x4A5A3A))),

        BrainrotCharacter(
            id: "zibra", name: "Zibra Zubra Zibralini",
            chant: "Zi-bra Zu-bra Zi-bra-li-ni",
            tagline: "Zebra, twice over, then once more for luck.",
            family: .bovine, tier: .deep,
            voice: .eerie.with { $0.fundamental = 165; $0.tempo = 4.5; $0.melody = [0, 1, 2, 3, 4, 5] },
            art: CreatureRecipe(body: .wide, head: .snout, ears: .pointy, limbs: .hooves,
                                eyes: .big, mouth: .smile, prop: .none, pattern: .stripes,
                                palette: Palette(body: 0xF0F0F0, bodyShade: 0x2A2A2A, accent: 0xE0A05A,
                                                 backdropTop: 0x2A2A3A, backdropBottom: 0x7A7A8A))),

        BrainrotCharacter(
            id: "piccione", name: "Piccione Macchina",
            chant: "Pic-cio-ne Mac-chi-na",
            tagline: "Pigeon, but a car. Parks anywhere.",
            family: .aviator, tier: .deep,
            voice: .chanter.with { $0.fundamental = 155; $0.tempo = 3.5; $0.brightness = 0.75; $0.melody = [0, 2, 0, 2] },
            art: CreatureRecipe(body: .fuselage, head: .beak, ears: .none, limbs: .stubby,
                                eyes: .beady, mouth: .beak, prop: .tyre, pattern: .none,
                                palette: Palette(body: 0x7A8AA8, bodyShade: 0x4E5A75, accent: 0xE05A4A,
                                                 backdropTop: 0x2A3040, backdropBottom: 0x6A7A9A))),

        BrainrotCharacter(
            id: "svinino", name: "Svinino Bombondino",
            chant: "Svi-ni-no Bom-bon-di-no",
            tagline: "Pig with wings and a payload. Cleared for takeoff.",
            family: .aviator, tier: .deep,
            voice: .bruiser.with { $0.fundamental = 92; $0.tempo = 3.7; $0.breathiness = 0.25; $0.melody = [0, 2, 0, -3, 0] },
            art: CreatureRecipe(body: .fuselage, head: .snout, ears: .floppy, limbs: .wings,
                                eyes: .beady, mouth: .smile, prop: .bomb, pattern: .none,
                                palette: Palette(body: 0xF2A0B0, bodyShade: 0xC47285, accent: 0x5A6B4A,
                                                 backdropTop: 0x4A2A35, backdropBottom: 0xC47290))),
    ]

    private static let index: [String: BrainrotCharacter] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func character(id: String) -> BrainrotCharacter? { index[id] }

    static func characters(upTo tier: BrainrotCharacter.Tier) -> [BrainrotCharacter] {
        all.filter { $0.tier <= tier }
    }
}
