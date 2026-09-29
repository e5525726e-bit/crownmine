/// Google 底圖樣式：關掉所有景點、商店、地標的圖示與名字，只留道路、地名與水域。
/// 餐飲店由 App 自己用大頭針標出。
const String kFoodOnlyMapStyle = '''
[
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "landscape.man_made", "elementType": "labels", "stylers": [{"visibility": "off"}]}
]
''';
