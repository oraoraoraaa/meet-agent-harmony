import { AppTheme } from './AppTheme';
import { AmapWebMapProvider, PoiHit } from '../services/map/AmapWebMapProvider';

@Component
export struct LocationSearchSheet {
  @Prop isDriver: boolean = true;
  @Prop mapKey: string = '';
  @Prop nearLon: number = 0;
  @Prop nearLat: number = 0;
  @Prop locating: boolean = false;
  onChoose: (hit: PoiHit) => void = () => {};
  onCurrent: () => void = () => {};
  onClose: () => void = () => {};
  @State query: string = '';
  @State hits: PoiHit[] = [];
  @State searching: boolean = false;
  @State message: string = '搜索地点名称、车站或地址';
  private inputController: TextInputController = new TextInputController();
  private revision: number = 0;
  private disposed: boolean = false;

  aboutToDisappear(): void { this.disposed = true; this.revision++; }

  private async search(): Promise<void> {
    if (this.searching || this.query.trim().length === 0) return;
    this.inputController.stopEditing();
    const token: number = ++this.revision;
    if (this.mapKey.trim().length === 0) {
      this.message = '请先在设置中配置高德 Web 服务 Key';
      return;
    }
    this.searching = true;
    this.hits = [];
    this.message = '正在搜索…';
    try {
      const provider: AmapWebMapProvider = new AmapWebMapProvider(this.mapKey);
      const hits: PoiHit[] = await provider.searchPoiDetailed(this.query.trim(), this.nearLon, this.nearLat, true, '');
      if (this.disposed || token !== this.revision) return;
      this.hits = hits;
      this.message = hits.length > 0 ? '选择地点即可更新位置' : '没有找到地点，请换个关键词或在地图选点';
    } catch (_) {
      if (!this.disposed && token === this.revision) this.message = '搜索暂不可用，请重试或在地图选点';
    } finally {
      if (!this.disposed && token === this.revision) this.searching = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor('#44000000').onClick(() => { this.onClose(); })
      Column({ space: 16 }) {
        Row() {
          Text(this.isDriver ? '司机出发地' : '乘客位置').fontSize(24).fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.ink).layoutWeight(1)
          Button('关闭').fontSize(14).height(36).backgroundColor(AppTheme.accentSoft)
            .fontColor(AppTheme.accent).onClick(() => { this.onClose(); })
        }.width('100%')
        Row({ space: 8 }) {
          TextInput({ text: this.query, placeholder: '搜索地点或地址', controller: this.inputController })
            .layoutWeight(1).height(48).backgroundColor(AppTheme.fieldBg)
            .onChange((value: string) => {
              this.query = value; this.revision++; this.searching = false; this.hits = [];
              this.message = '搜索地点名称、车站或地址';
            })
            .onSubmit(() => { this.search(); })
          Button('搜索').height(48).fontSize(14).backgroundColor(AppTheme.accent).fontColor(Color.White)
            .enabled(!this.searching && this.query.trim().length > 0).onClick(() => { this.search(); })
        }.width('100%')
        Button(this.locating ? '正在获取位置…' : '使用当前位置').width('100%').height(44)
          .fontColor(AppTheme.accent).backgroundColor(AppTheme.accentSoft).enabled(!this.locating)
          .onClick(() => { this.onCurrent(); })
        Text(this.message).fontSize(13).fontColor(AppTheme.inkSoft).width('100%')
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.hits, (hit: PoiHit, index: number) => {
              Column({ space: 5 }) {
                Text(hit.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.ink)
                Text(hit.address).fontSize(13).fontColor(AppTheme.inkSoft)
              }.alignItems(HorizontalAlign.Start).width('100%').padding(16)
                .backgroundColor(AppTheme.fieldBg).borderRadius(14).id(`location-hit-${index}`).onClick(() => { this.onChoose(hit); })
            })
          }.width('100%')
        }.layoutWeight(1).width('100%').align(Alignment.TopStart).scrollBar(BarState.Off)
        Button('在地图上选点').width('100%').height(40).backgroundColor(Color.Transparent)
          .fontColor(AppTheme.accent).onClick(() => { this.onClose(); })
      }.height('78%').width('100%').padding({ left: 22, right: 22, top: 24, bottom: 26 })
        .backgroundColor(AppTheme.bg1).borderRadius({ topLeft: 28, topRight: 28 })
    }.width('100%').height('100%')
  }
}
