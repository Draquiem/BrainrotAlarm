import Foundation

/// A recipe for drawing one brainrot creature.
///
/// The art is generated from these parts rather than shipped as images: every
/// character in this meme family is some animal welded to some object, so a small
/// parts vocabulary covers the whole roster, stays sharp at any size, adds nothing
/// to the bundle, and sidesteps using artwork nobody here owns.
struct CreatureRecipe: Equatable {

    enum Body: Equatable {
        case blob        // generic rounded creature
        case pear        // narrow shoulders, heavy bottom
        case tall        // upright capsule
        case wide        // horizontal capsule, four legs
        case fruit       // sphere with a stem
        case cup         // tapered drinking vessel
        case log         // rounded rectangle, wooden
        case fuselage    // aircraft body
    }

    enum Head: Equatable {
        case round
        case snout       // round with a muzzle
        case wedge       // shark / crocodile
        case beak
        case box
        case merged      // no separate head
    }

    enum Ears: Equatable {
        case none, round, pointy, floppy, horns, fin, antennae, leaf
    }

    enum Limbs: Equatable {
        case none, stubby, long, fins, wings, tentacles, hooves
    }

    enum Eyes: Equatable {
        case big, googly, sleepy, beady, shades, single
    }

    enum Mouth: Equatable {
        case smile, fangs, beak, gasp, flat, grin
    }

    /// The object half of the mash-up.
    enum Prop: Equatable {
        case none, sneakers, bomb, coffeeCup, banana, cactus, drumstick, planetRing
        case melon, pineapple, tyre, coconut, berry, ball, clock, cigar, fridge
        case propeller, sparkles, blade, tutu
    }

    enum Pattern: Equatable {
        case none, stripes, spots, scales, checker, swirl
    }

    var body: Body
    var head: Head
    var ears: Ears
    var limbs: Limbs
    var eyes: Eyes
    var mouth: Mouth
    var prop: Prop
    var pattern: Pattern
    var palette: Palette
    /// Small per-character jitter so silhouettes do not line up exactly.
    var tilt: Double = 0
    var chonk: Double = 1.0
}
