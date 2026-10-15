/**
 * 柱状图：多方案月利润对比（正值红、负值绿，遵循涨红跌绿惯例）
 */
@Component
export struct BarChart {
  @Prop @Watch('onDataChange') values: number[] = [];
  @Prop @Watch('onDataChange') labels: string[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private readonly palette: string[] = ['#e8684a', '#5b8ff9', '#5ad8a6', '#f6bd16', '#7262fd'];

  onDataChange(): void {
    if (this.ready) {
      this.draw();
    }
  }

  onReadyCanvas(): void {
    this.ready = true;
    this.draw();
  }

  private draw(): void {
    const ctx = this.ctx;
    const w = this.ctx.width;
    const h = this.ctx.height;
    ctx.clearRect(0, 0, w, h);
    const n = this.values.length;
    if (n === 0) {
      return;
    }
    const padL = 16;
    const padB = 34;
    const padT = 16;
    let maxV = 0;
    let minV = 0;
    for (const v of this.values) {
      if (v > maxV) {
        maxV = v;
      }
      if (v < minV) {
        minV = v;
      }
    }
    if (maxV === minV) {
      maxV = minV + 1;
    }
    const range = maxV - minV;
    const plotH = h - padT - padB;
    const zeroY = padT + plotH * (maxV / range);
    const slot = (w - padL * 2) / n;
    const barW = Math.min(slot * 0.5, 60);

    // 零轴
    ctx.strokeStyle = '#999999';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(padL, zeroY);
    ctx.lineTo(w - padL, zeroY);
    ctx.stroke();

    for (let i = 0; i < n; i++) {
      const v = this.values[i];
      const x = padL + slot * i + (slot - barW) / 2;
      const valH = Math.abs(v) / range * plotH;
      if (v >= 0) {
        ctx.fillStyle = this.palette[i % this.palette.length];
        ctx.fillRect(x, zeroY - valH, barW, valH);
      } else {
        ctx.fillStyle = '#2e9e6b';
        ctx.fillRect(x, zeroY, barW, valH);
      }
      // 标签
      ctx.fillStyle = '#666666';
      ctx.font = '12px sans-serif';
      ctx.textAlign = 'center';
      const label = i < this.labels.length ? this.labels[i] : '';
      ctx.fillText(label, x + barW / 2, h - padB + 16);
      // 数值
      ctx.fillStyle = '#333333';
      const valText = Math.abs(v) >= 10000 ? `${(v / 10000).toFixed(1)}万` : `${Math.round(v)}`;
      ctx.fillText(valText, x + barW / 2, v >= 0 ? zeroY - valH - 4 : zeroY + valH + 14);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(220)
      .onReady(() => this.onReadyCanvas())
  }
}
