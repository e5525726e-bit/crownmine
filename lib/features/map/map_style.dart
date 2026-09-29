/// Google 底圖樣式：關掉景點、商店、地標的圖示與名字，只留道路、地名、水域，
/// 並把大眾運輸（捷運、火車、高鐵）的路線加粗上色、車站圖示與名字強制顯示。
/// 餐飲店由 App 自己用大頭針標出。
const String kFoodOnlyMapStyle = '''
[
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit.line", "elementType": "geometry", "stylers": [{"visibility": "on"}, {"color": "#5B4FE9"}, {"weight": 2.5}]},
  {"featureType": "transit.line", "elementType": "labels", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit.station.rail", "elementType": "labels.icon", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit.station.rail", "elementType": "labels.text", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit.station.airport", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit.station.bus", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "landscape.man_made", "elementType": "labels", "stylers": [{"visibility": "off"}]}
]
''';
