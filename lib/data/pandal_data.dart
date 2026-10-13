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
  'Memari',
  'Borshul',
  'Dhaniakhali',
  'Jamalpur',
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
    area: 'All areas',
    stop: PandalStop(
      id: 'angel-ivf-diagnostic-centre',
      name: 'Angel IVF & Diagnostic Centre',
      latitude: 23.04416849652586,
      longitude: 87.98542282148246,
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
  /// Memari Pandal stops
  //===================================
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'memari-checkpost-bus-stop',
      name: 'Memari CheckPost Bus stop',
      latitude: 23.177736186045138,
      longitude: 88.0902941798166,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'dakshin-memari-durga-mandir',
      name: 'Dakshin Memari Durga Mandir',
      latitude: 23.16920528616337,
      longitude: 88.09654078845605,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'sridurgapally-durga-puja',
      name: 'Sridurgapally Durga Puja',
      latitude: 23.171179143225938,
      longitude: 88.09507147527822,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'someshwar-temple',
      name: 'Someshwar Temple',
      latitude: 23.17434452239649,
      longitude: 88.09907995191938,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'memari-hospital-more-bus-stop',
      name: 'Memari Hospital More Bus Stop',
      latitude: 23.17931189786687,
      longitude: 88.10270430771216,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'memari-new-bus-stand-durga-pujo',
      name: 'Memari New bus stand durga pujo',
      latitude: 23.176463254896415,
      longitude: 88.09459493977177,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'memari-sonapatti-sarbojonin-durga-puja',
      name: 'Memari Sonapatti Sarbojonin Durga Puja',
      latitude: 23.173207829176203,
      longitude: 88.09923755111222,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'krishna-bazer-sarbojonin-durga-puja',
      name: 'Krishna Bazer Sarbojonin Durga Puja',
      latitude: 23.170551933016803,
      longitude: 88.10008512481403,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'memari-duttapara-laha-pujabari',
      name: 'Memari Duttapara Laha Pujabari',
      latitude: 23.172742647961584,
      longitude: 88.09995448583096,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'mayer-kole-sarbojonin-durga-puja',
      name: 'Mayer Kole Sarbojonin Durga Puja',
      latitude: 23.17838649218034,
      longitude: 88.09902799913276,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'memari-saradanjali-sarbojonin-durga-puja',
      name: 'Memari Saradanjali Sarbojonin Durga Puja',
      latitude: 23.179153130718067,
      longitude: 88.0886596534033,
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'memari-station-bazaar-sarbojonin-durga-puja',
      name: 'Memari Station Bazaar Sarbojonin Durga Puja',
      latitude: 23.172940289504663,
      longitude: 88.09699823301276
    ),
  ),
  PandalEntry(
    area: 'Memari',
    stop: PandalStop(
      id: 'saradapally-aurobindapally-durga-puja-mandap',
      name: 'Saradapally & Aurobindapally Durga Puja Mandap',
      latitude: 23.177698590244397,
      longitude: 88.09260443312256,
    ),
  ),
  //===================================
  /// Borshul Pandal stops
  //===================================
  PandalEntry(
    area: 'Borshul',
    stop: PandalStop(
      id: 'barsul-young-mens-association',
      name: "Barsul Young Mens' Association",
      latitude: 23.18396470670496,
      longitude: 87.96315117255027,
    ),
  ),
  PandalEntry(
    area: 'Borshul',
    stop: PandalStop(
      id: 'byma-durga-puja',
      name: 'BYMA DURGA PUJA',
      latitude: 23.182428671225463,
      longitude: 87.96402741788629,
    ),
  ),
  PandalEntry(
    area: 'Borshul',
    stop: PandalStop(
      id: 'barsul-jagarani-club',
      name: 'Barsul Jagarani Club',
      latitude: 23.183302452736804,
      longitude: 87.96177927768912,
    ),
  ),
  PandalEntry(
    area: 'Borshul',
    stop: PandalStop(
      id: 'annadapalli-jamini-smriti-sangha-barsul',
      name: 'Annadapalli Jamini Smriti Sangha, Barsul',
      latitude: 23.18534979315168,
      longitude: 87.97188400864754,
    ),
  ),


  //===================================
  /// Jamalpur Pandal stops
  //===================================
  PandalEntry(
    area: 'Jamalpur',
    stop: PandalStop(
      id: 'harala-durgatola',
      name: 'HARALA DURGATOLA',
      latitude: 23.0425,
      longitude: 87.9710,
    ),
  ),
  PandalEntry(
    area: 'Jamalpur',
    stop: PandalStop(
      id: 'jamalpur-netaji-math',
      name: 'Jamalpur Netaji Math',
      latitude: 23.0330,
      longitude: 87.9620,
    ),
  ),
  PandalEntry(
    area: 'Jamalpur',
    stop: PandalStop(
      id: 'toll-booth',
      name: 'Toll Booth',
      latitude: 23.0380,
      longitude: 87.9540,
    ),
  ),
  PandalEntry(
    area: 'Jamalpur',
    stop: PandalStop(
      id: 'kanshra-bhubaneswar-tala-shiva-temple',
      name: 'Kanshra Bhubaneswar Tala Shiva Temple',
      latitude: 23.0080,
      longitude: 87.9580,
    ),
  ),

  //===================================
  /// Dhaniakhali Pandal stops
  //===================================

  PandalEntry(
    area: 'Dhaniakhali',
    stop: PandalStop(
      id: 'chakdighi-milan-sangha',
      name: 'Chakdighi Milan Sangha',
      latitude: 22.9560,
      longitude: 87.9610,
    ),
  ),
  PandalEntry(
    area: 'Dhaniakhali',
    stop: PandalStop(
      id: 'dasghara-bazarpara-sarbojonin-durga-puja-pandal',
      name: 'Dasghara Bazarpara Sarbojonin Durga Puja pandal',
      latitude: 22.9320,
      longitude: 87.9940,
    ),
  ),
  PandalEntry(
    area: 'Dhaniakhali',
    stop: PandalStop(
      id: 'kananadi-durgapuja',
      name: 'Kananadi Durgapuja',
      latitude: 22.9360,
      longitude: 88.0290,
    ),
  ),
  PandalEntry(
    area: 'Dhaniakhali',
    stop: PandalStop(
      id: 'rohia-nabin-sangha',
      name: 'Rohia Nabin Sangha',
      latitude: 22.9730,
      longitude: 88.0820,
    ),
  ),
  PandalEntry(
    area: 'Dhaniakhali',
    stop: PandalStop(
      id: 'dhaniakhali-bus-terminus',
      name: 'Dhaniakhali Bus Terminus',
      latitude: 22.9520,
      longitude: 88.0850,
    ),
  ),
  PandalEntry(
    area: 'Dhaniakhali',
    stop: PandalStop(
      id: 'mukundapur-durga-puja-mandap',
      name: 'Mukundapur Durga Puja Mandap',
      latitude: 22.9430,
      longitude: 88.0690,
    ),
  ),

  //===================================
  /// Tarakeswar Pandal stops
  //===================================

  PandalEntry(
    area: 'Tarakeswar',
    stop: PandalStop(
      id: 'bhootnath-mandir',
      name: 'Bhootnath mandir',
      latitude: 22.8850,
      longitude: 88.0220,
    ),
  ),
  PandalEntry(
    area: 'Tarakeswar',
    stop: PandalStop(
      id: 'hooghly-west-bengal-712410',
      name: 'Hooghly West Bengal 712410',
      latitude: 22.9000,
      longitude: 88.0200,
    ),
  ),
  PandalEntry(
    area: 'Tarakeswar',
    stop: PandalStop(
      id: 'durga-mandir',
      name: 'Durga Mandir',
      latitude: 22.9100,
      longitude: 88.0050,
    ),
  ),
  PandalEntry(
    area: 'Tarakeswar',
    stop: PandalStop(
      id: 'tarkeshwar',
      name: 'Tarkeshwar',
      latitude: 22.8875,
      longitude: 88.0245,
    ),
  ),
  PandalEntry(
    area: 'Tarakeswar',
    stop: PandalStop(
      id: 'ths-durga-puja-pandal',
      name: 'THS durga puja pandal',
      latitude: 22.8900,
      longitude: 88.0150,
    ),
  ),
  PandalEntry(
    area: 'Tarakeswar',
    stop: PandalStop(
      id: 'sahapur-playground',
      name: 'Sahapur Playground',
      latitude: 22.8900,
      longitude: 88.0190,
    ),
  ),
  PandalEntry(
    area: 'Tarakeswar',
    stop: PandalStop(
      id: 'netaji-subhas-road-durga-puja-committee',
      name: 'Netaji Subhas Road Durga Puja Committee',
      latitude: 22.8890,
      longitude: 88.0210,
    ),
  ),
  PandalEntry(
    area: 'Tarakeswar',
    stop: PandalStop(
      id: 'chaoulpatty-durgamata-temple',
      name: 'Chaoulpatty Durgamata Temple',
      latitude: 22.8860,
      longitude: 88.0230,
    ),
  ),

];