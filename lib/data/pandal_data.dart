import '../providers/navigation_provider.dart';

class PandalEntry {
  const PandalEntry({
    required this.stop,
    required this.area,
  });

  final PandalStop stop;
  final String area;
}

const List<String> pandalAreas = [
  'All areas',
  'Kolkata',
  'Bardhaman',
  'Tarakeswar',
];

const List<PandalEntry> pandalCatalog = [
  PandalEntry(
    area: 'All areas',
    stop: PandalStop(
      id: 'home',
      name: 'Home',
      latitude: 23.02724227874506,
      longitude: 87.97323247175703,
    ),
  ),
  PandalEntry(
    area: 'Kolkata',
    stop: PandalStop(
      id: 'college-square',
      name: 'College Square',
      latitude: 22.5744,
      longitude: 88.3639,
    ),
  ),
  PandalEntry(
    area: 'Kolkata',
    stop: PandalStop(
      id: 'kumartuli-sarbojanin',
      name: 'Kumartuli Sarbojanin',
      latitude: 22.6020,
      longitude: 88.3609,
    ),
  ),
  PandalEntry(
    area: 'Kolkata',
    stop: PandalStop(
      id: 'bagbazar-sarbojanin',
      name: 'Bagbazar Sarbojanin',
      latitude: 22.5995,
      longitude: 88.3690,
    ),
  ),
  PandalEntry(
    area: 'Kolkata',
    stop: PandalStop(
      id: 'md-ali-park',
      name: 'Md Ali Park',
      latitude: 22.5738,
      longitude: 88.3582,
    ),
  ),

  //===================================
  /// Bardhaman Pandal stops
  //===================================
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'mayur-mahal',
      name: 'Mayur Mahal',
      latitude: 23.235965,
      longitude: 87.853797,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'alamganj-durga-mandir',
      name: 'Alamganj Durga Mandir',
      latitude: 23.232573619848743,
      longitude: 87.84955193755071,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'sukanta-smriti-sangha',
      name: 'Sukanta Smriti Sangha',
      latitude: 23.220840090234994,
      longitude: 87.852447735795,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'vivekananda-sevak-sangha',
      name: 'Vivekananda Sevak Sangha',
      latitude: 23.23203676484892,
      longitude: 87.86456373925871,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'laltu-smriti-sangha',
      name: 'Laltu Smriti Sangha',
      latitude: 23.229067999182604,
      longitude: 87.86919042524103,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'ichlabad-youth-club-play-ground',
      name: 'Ichlabad Youth Club Play Ground',
      latitude: 23.227792470465506,
      longitude: 87.88033021212857,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'sarba-milan-sangha',
      name: 'Sarba Milan Sangha',
      latitude: 23.21864217939116,
      longitude: 87.88041525172895,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'ghordour-choti-sharbojonin-durga-puja',
      name: 'Ghordour Choti Sharbojonin Durga Puja',
      latitude: 23.221735,
      longitude: 87.883694,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'padmashree-sangha-playground',
      name: 'Padmashree Sangha Playground',
      latitude: 23.227776712320587,
      longitude: 87.8754272164978,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'sabuj-sangha-durga-puja-pandel',
      name: 'Sabuj Sangha Durga Puja Pandel',
      latitude: 23.228339333315194,
      longitude: 87.8731384438204,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'burir-bagan-sarbojonin-durgatala',
      name: 'Burir Bagan Sarbojonin Durgatala',
      latitude: 23.246133048624035,
      longitude: 87.86497460714251,
    ),
  ),
  PandalEntry(
    area: 'Bardhaman',
    stop: PandalStop(
      id: 'bajepratappur-traffic-colony-durgapuja-committee',
      name: 'Bajepratappur Traffic Colony Durgapuja Committee',
      latitude: 23.253471061584147,
      longitude: 87.87063593076678,
    ),
  ),

  //===================================
  /// Tarakeswar Pandal stops
  //===================================
  // Add verified pandals for Bardhaman and Tarakeswar here.
  // Use each pandal's actual latitude and longitude.
];