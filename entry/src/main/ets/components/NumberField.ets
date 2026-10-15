/**
 * 数值输入行：标签 + 输入框 + 单位
 */
@Component
export struct NumberField {
  @Prop label: string = '';
  @Prop unit: string = '';
  @Link value: number;
  @State text: string = '';
  private inited: boolean = false;

  aboutToAppear(): void {
    if (!this.inited) {
      this.text = this.value.toString();
      this.inited = true;
    }
  }

  build() {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      Row({ space: 6 }) {
        TextInput({ text: this.text, placeholder: '0' })
          .layoutWeight(1)
          .height(38)
          .fontSize(15)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onChange((v: string) => {
            this.text = v;
            const n = Number(v);
            if (v.length > 0 && !Number.isNaN(n)) {
              this.value = n;
            }
          })
        Text(this.unit)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .width(52)
      }
      .width('100%')
    }
    .width('100%')
  }
}
