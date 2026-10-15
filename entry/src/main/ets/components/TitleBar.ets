/**
 * 通用页头：圆形返回按钮 + 品牌色竖条 + 标题/副标题
 */
import { router } from '@kit.ArkUI';
import { C_BRAND, C_BRAND_2 } from '../common/Theme';

@Component
export struct TitleBar {
  @Prop title: string = '';
  @Prop subtitle: string = '';

  build() {
    Row({ space: 14 }) {
      Text('←')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(C_BRAND)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .borderRadius(20)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .onClick(() => router.back())

      Row({ space: 10 }) {
        Row()
          .width(5)
          .height(22)
          .borderRadius(3)
          .linearGradient({
            angle: 180,
            colors: [[C_BRAND, 0.0], [C_BRAND_2, 1.0]]
          })
        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
  }
}
