/// Google 底圖樣式：關掉景點、商店、地標的圖示與名字，只留道路、地名、水域，
/// 以及大眾運輸（捷運、火車、高鐵的路線與車站）。餐飲店由 App 自己用大頭針標出。
const String kFoodOnlyMapStyle = '''
[
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit.line", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit.station.rail", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit.station.bus", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit.station.airport", "stylers": [{"visibility": "on"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "landscape.man_made", "elementType": "labels", "stylers": [{"visibility": "off"}]}
]
''';
