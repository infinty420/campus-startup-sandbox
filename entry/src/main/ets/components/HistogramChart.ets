/**
 * 直方图：12 月末现金分布（负值桶红色警示）
 */
@Component
export struct HistogramChart {
  @Prop @Watch('onDataChange') bins: number[] = [];
  @Prop @Watch('onDataChange') start: number = 0;
  @Prop @Watch('onDataChange') step: number = 1;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  onDataChange(): void {
    if (this.ready) {
      this.draw();
    }
  }

  onReadyCanvas(): void {
    this.ready = true;
    this.draw();
  }

  private fmt(v: number): string {
    if (Math.abs(v) >= 10000) {
      return `${(v / 10000).toFixed(1)}万`;
    }
    return `${Math.round(v)}`;
  }

  private draw(): void {
    const ctx = this.ctx;
    const w = this.ctx.width;
    const h = this.ctx.height;
    ctx.clearRect(0, 0, w, h);
    const n = this.bins.length;
    if (n === 0 || this.step <= 0) {
      return;
    }
    const padL = 16;
    const padR = 16;
    const padB = 26;
    const padT = 14;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;
    let maxCnt = 0;
    for (const c of this.bins) {
      if (c > maxCnt) {
        maxCnt = c;
      }
    }
    if (maxCnt === 0) {
      return;
    }
    const slot = plotW / n;
    const barW = slot * 0.82;

    for (let i = 0; i < n; i++) {
      const binCenter = this.start + (i + 0.5) * this.step;
      const x = padL + slot * i + (slot - barW) / 2;
      const bh = this.bins[i] / maxCnt * plotH;
      ctx.fillStyle = binCenter < 0 ? '#d03050' : '#5b8ff9';
      ctx.fillRect(x, padT + plotH - bh, barW, bh);
    }

    // 底轴
    ctx.strokeStyle = '#999999';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(padL, padT + plotH);
    ctx.lineTo(w - padR, padT + plotH);
    ctx.stroke();
    // 刻度：首/中/尾
    ctx.fillStyle = '#666666';
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText(this.fmt(this.start), padL, h - 8);
    ctx.textAlign = 'center';
    ctx.fillText(this.fmt(this.start + n / 2 * this.step), padL + plotW / 2, h - 8);
    ctx.textAlign = 'right';
    ctx.fillText(this.fmt(this.start + n * this.step), w - padR, h - 8);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(200)
      .onReady(() => this.onReadyCanvas())
  }
}
