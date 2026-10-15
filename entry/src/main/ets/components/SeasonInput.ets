/**
 * 季节系数单元格：月份标签 + 数值输入
 */
@Component
export struct SeasonInput {
  @Prop monthIdx: number = 0;
  @Prop val: number = 1;
  onVal: (m: number, v: number) => void = () => {
  };

  build() {
    Column({ space: 2 }) {
      Text(`${this.monthIdx + 1}月`)
        .fontSize(10)
        .fontColor($r('sys.color.font_tertiary'))
      TextInput({ text: this.val.toString() })
        .fontSize(13)
        .height(32)
        .width(54)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onChange((t: string) => {
          const n = Number(t);
          if (t.length > 0 && !Number.isNaN(n)) {
            this.onVal(this.monthIdx, n);
          }
        })
    }
  }
}
