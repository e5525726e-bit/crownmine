import 'package:crownmine/models/tw_city.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('座標判斷縣市', () {
    expect(cityAt(25.0418, 121.5436)?.name, '台北市'); // 台北車站
    expect(cityAt(25.1700, 121.4400)?.name, '新北市'); // 淡水（板橋等邊界點粗略判斷會錯，實際靠地址）
    expect(cityAt(22.6273, 120.3014)?.name, '高雄市');
    expect(cityAt(23.4801, 120.4491)?.name, '嘉義市');
    expect(cityAt(35.0, 139.0), isNull);
  });

  test('文字裡的縣市', () {
    expect(cityInText('台中 火鍋')?.name, '台中市');
    expect(cityInText('新北市板橋 拉麵')?.name, '新北市');
    expect(cityInText('臺北 咖啡')?.name, '台北市');
    expect(cityInText('火鍋'), isNull);
  });

  test('地址判斷縣市', () {
    expect(cityOfAddress('403臺中市西區台灣大道二段')?.name, '台中市');
    expect(cityOfAddress('600嘉義市東區')?.name, '嘉義市');
    expect(cityOfAddress('621嘉義縣民雄鄉')?.name, '嘉義縣');
    expect(cityOfAddress('Tokyo'), isNull);
  });

  test('地址比對', () {
    const taipei = TwCity('台北市', ['台北市', '臺北市'], 0, 0, 1, 1);
    expect(taipei.inAddress('100臺北市中正區忠孝西路一段'), isTrue);
    expect(taipei.inAddress('220新北市板橋區'), isFalse);
  });
}
