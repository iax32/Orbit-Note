import 'package:flutter/material.dart';

/// Supported types of visual atmosphere effects for virtual reading rooms.
enum RoomAtmosphereType { rain, fireplace, midnight, train, forest, cafe }

/// An ambient sound channel with volume and mute controls.
class AmbientSoundChannel {
  AmbientSoundChannel({
    required this.id,
    required this.name,
    double volume = 0.6,
    this.isMuted = false,
  }) : _volume = volume.clamp(0.0, 1.0);

  final String id;
  final String name;
  double _volume;
  double get volume => _volume;
  set volume(double val) => _volume = val.clamp(0.0, 1.0);
  bool isMuted;

  AmbientSoundChannel copyWith({
    String? id,
    String? name,
    double? volume,
    bool? isMuted,
  }) {
    return AmbientSoundChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

/// A cozy virtual environment for deep, immersive reading sessions.
class ReadingRoom {
  const ReadingRoom({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.primaryTone,
    required this.accentTone,
    required this.atmosphereType,
    required this.soundChannels,
  });

  final String id;
  final String name;
  final String tagline;
  final String description;
  final IconData icon;
  final Color primaryTone;
  final Color accentTone;
  final RoomAtmosphereType atmosphereType;
  final List<AmbientSoundChannel> soundChannels;
}

/// Built-in catalog of virtual reading rooms.
class ReadingRoomCatalog {
  const ReadingRoomCatalog._();

  static final rainyLibrary = ReadingRoom(
    id: 'rainy_library',
    name: 'Rainy Library',
    tagline: 'Rain outside, warm amber lamps, quiet bookshelves',
    description:
        'Soft raindrops trickling against dark window glass, rich wooden study tables, and the soothing rhythm of distant storm clouds.',
    icon: Icons.water_drop_outlined,
    primaryTone: const Color(0xFF14171F),
    accentTone: const Color(0xFF7EA5D9),
    atmosphereType: RoomAtmosphereType.rain,
    soundChannels: [
      AmbientSoundChannel(id: 'rain', name: 'Window Rain', volume: 0.7),
      AmbientSoundChannel(id: 'thunder', name: 'Distant Thunder', volume: 0.4),
      AmbientSoundChannel(id: 'pages', name: 'Turning Pages', volume: 0.3),
    ],
  );

  static final fireplaceCabin = ReadingRoom(
    id: 'fireplace_cabin',
    name: 'Fireplace Cabin',
    tagline: 'Snow outside, hearth crackle, cozy dim warmth',
    description:
        'A remote timber haven surrounded by fresh winter snow, glowing embers resting in the hearth with warm comforting radiance.',
    icon: Icons.local_fire_department_outlined,
    primaryTone: const Color(0xFF171412),
    accentTone: const Color(0xFFD97746),
    atmosphereType: RoomAtmosphereType.fireplace,
    soundChannels: [
      AmbientSoundChannel(id: 'fire', name: 'Hearth Crackle', volume: 0.75),
      AmbientSoundChannel(id: 'blizzard', name: 'Wind & Snow', volume: 0.35),
      AmbientSoundChannel(id: 'clock', name: 'Antique Clock', volume: 0.25),
    ],
  );

  static final midnightStudy = ReadingRoom(
    id: 'midnight_study',
    name: 'Midnight Study',
    tagline: 'Dark observatory desk, city lights, quiet twilight',
    description:
        'High floor overlooking quiet distant city skylines, cool graphite architecture with a focused brass desk lamp for nocturnal concentration.',
    icon: Icons.nightlight_round,
    primaryTone: const Color(0xFF12141C),
    accentTone: const Color(0xFF9386E8),
    atmosphereType: RoomAtmosphereType.midnight,
    soundChannels: [
      AmbientSoundChannel(id: 'city', name: 'Night Cityscape', volume: 0.4),
      AmbientSoundChannel(id: 'tape', name: 'Soft Lo-Fi Noise', volume: 0.3),
      AmbientSoundChannel(id: 'crickets', name: 'Night Breeze', volume: 0.3),
    ],
  );

  static final nightTrain = ReadingRoom(
    id: 'night_train',
    name: 'Night Train',
    tagline: 'Private compartment, rhythmic rails, moving horizon',
    description:
        'A mahogany Pullman carriage swaying gently through misty midnight mountains, lantern reflections drifting across window glass.',
    icon: Icons.train_outlined,
    primaryTone: const Color(0xFF13151C),
    accentTone: const Color(0xFF6898B8),
    atmosphereType: RoomAtmosphereType.train,
    soundChannels: [
      AmbientSoundChannel(
        id: 'train_rhythm',
        name: 'Rail Rhythm',
        volume: 0.65,
      ),
      AmbientSoundChannel(
        id: 'cabin_hum',
        name: 'Compartment Hum',
        volume: 0.3,
      ),
      AmbientSoundChannel(id: 'whistle', name: 'Distant Whistle', volume: 0.2),
    ],
  );

  static final forestCabin = ReadingRoom(
    id: 'forest_cabin',
    name: 'Forest Cabin',
    tagline: 'Pine needles, dappled sun, woodland breeze',
    description:
        'Sunlight filtering softly through cedar branches, birds chirping in morning tranquility with fresh mountain pine air.',
    icon: Icons.forest_outlined,
    primaryTone: const Color(0xFF121714),
    accentTone: const Color(0xFF5FA885),
    atmosphereType: RoomAtmosphereType.forest,
    soundChannels: [
      AmbientSoundChannel(id: 'birds', name: 'Forest Birds', volume: 0.5),
      AmbientSoundChannel(id: 'leaves', name: 'Rustling Leaves', volume: 0.5),
      AmbientSoundChannel(id: 'stream', name: 'Mountain Stream', volume: 0.4),
    ],
  );

  static final cozyCafe = ReadingRoom(
    id: 'cozy_cafe',
    name: 'Cozy Café',
    tagline: 'Warm terracotta, soft murmur, steaming coffee',
    description:
        'A tucked-away Parisian corner café with velvet chairs, porcelain cups clinking, and the warm aroma of fresh espresso in rainy afternoon light.',
    icon: Icons.coffee_outlined,
    primaryTone: const Color(0xFF171311),
    accentTone: const Color(0xFFC8935C),
    atmosphereType: RoomAtmosphereType.cafe,
    soundChannels: [
      AmbientSoundChannel(id: 'murmur', name: 'Bistro Murmur', volume: 0.45),
      AmbientSoundChannel(
        id: 'espresso',
        name: 'Coffee Grinder & Steam',
        volume: 0.35,
      ),
      AmbientSoundChannel(id: 'jazz', name: 'Subtle Jazz Bass', volume: 0.4),
    ],
  );

  static final List<ReadingRoom> all = [
    rainyLibrary,
    fireplaceCabin,
    midnightStudy,
    nightTrain,
    forestCabin,
    cozyCafe,
  ];

  static ReadingRoom byId(String id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return rainyLibrary;
  }
}
