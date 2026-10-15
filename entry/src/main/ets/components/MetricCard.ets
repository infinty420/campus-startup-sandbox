/**
 * 指标卡片
 */
@Component
export struct MetricCard {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop sub: string = '';
  @Prop color: string = '';

  build() {
    Column({ space: 4 }) {
      Text(this.title)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
      Text(this.value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.color.length > 0 ? this.color : $r('sys.color.font_primary'))
      if (this.sub.length > 0) {
        Text(this.sub)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(10)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .width('100%')
  }
}
