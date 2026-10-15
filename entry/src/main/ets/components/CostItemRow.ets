/**
 * 成本条目编辑行：名称 + 类型 + 金额 +（摊销月数 / 生效区间）
 */
import { CostItem, CostKind } from '../model/PlanV2';

const KIND_ORDER: CostKind[] = ['onetime', 'monthly', 'perUnit', 'amortized'];
const KIND_LABEL: Record<string, string> = {
  'onetime': '一次性',
  'monthly': '按月',
  'perUnit': '按单',
  'amortized': '按月摊销'
};

function kindLabel(k: string): string {
  return KIND_LABEL[k] !== undefined ? KIND_LABEL[k] : '按月';
}

function kindIndex(k: string): number {
  const i = KIND_ORDER.indexOf(k as CostKind);
  return i >= 0 ? i : 1;
}

@Component
export struct CostItemRow {
  @Prop item: CostItem;
  onUpdateNum: (field: string, val: number) => void = () => {
  };
  onUpdateStr: (field: string, val: string) => void = () => {
  };
  onDelete: () => void = () => {
  };
  @State nameText: string = '';
  @State amountText: string = '';
  @State amortText: string = '';
  @State startText: string = '';
  @State endText: string = '';

  aboutToAppear(): void {
    this.nameText = this.item.name;
    this.amountText = `${this.item.amount}`;
    this.amortText = `${this.item.amortMonths}`;
    this.startText = `${this.item.startMonth}`;
    this.endText = `${this.item.endMonth}`;
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        TextInput({ text: this.nameText, placeholder: '成本名称' })
          .layoutWeight(1)
          .height(34)
          .fontSize(14)
          .onChange((v: string) => {
            this.nameText = v;
            this.onUpdateStr('name', v);
          })
        Text('删除')
          .fontSize(12)
          .fontColor('#d03050')
          .padding(6)
          .onClick(() => this.onDelete())
      }
      .width('100%')

      Row({ space: 6 }) {
        Select([
          { value: '一次性' },
          { value: '按月' },
          { value: '按单' },
          { value: '按月摊销' }
        ])
          .selected(kindIndex(this.item.kind))
          .value(kindLabel(this.item.kind))
          .font({ size: 13 })
          .height(34)
          .width(110)
          .onSelect((idx: number) => {
            this.onUpdateStr('kind', KIND_ORDER[idx]);
          })
        TextInput({ text: this.amountText, placeholder: '金额' })
          .height(34)
          .fontSize(14)
          .width(110)
          .onChange((v: string) => {
            this.amountText = v;
            const n = Number(v);
            if (v.length > 0 && !Number.isNaN(n)) {
              this.onUpdateNum('amount', n);
            }
          })
        Text(this.item.kind === 'perUnit' ? '元/单' : '元')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        if (this.item.kind === 'amortized') {
          TextInput({ text: this.amortText, placeholder: '摊销' })
            .height(34)
            .fontSize(14)
            .width(70)
            .onChange((v: string) => {
              this.amortText = v;
              const n = Number(v);
              if (v.length > 0 && !Number.isNaN(n)) {
                this.onUpdateNum('amortMonths', n);
              }
            })
          Text('月摊完')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
        }
        if (this.item.kind === 'monthly') {
          TextInput({ text: this.startText })
            .height(34)
            .fontSize(14)
            .width(50)
            .onChange((v: string) => {
              this.startText = v;
              const n = Number(v);
              if (v.length > 0 && !Number.isNaN(n)) {
                this.onUpdateNum('startMonth', n);
              }
            })
          Text('至')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
          TextInput({ text: this.endText })
            .height(34)
            .fontSize(14)
            .width(50)
            .onChange((v: string) => {
              this.endText = v;
              const n = Number(v);
              if (v.length > 0 && !Number.isNaN(n)) {
                this.onUpdateNum('endMonth', n);
              }
            })
          Text('月')
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
      .width('100%')
    }
    .padding(10)
    .borderRadius(10)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .width('100%')
  }
}
