/**
 * 折线图：多方案 12 个月累计现金流
 */
@Component
export struct CashFlowChart {
  @Prop @Watch('onDataChange') series: number[][] = [];
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
    if (this.series.length === 0) {
      return;
    }
    const padL = 46;
    const padR = 16;
    const padT = 16;
    const padB = 26;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;

    let maxV = 0;
    let minV = 0;
    for (const line of this.series) {
      for (const v of line) {
        if (v > maxV) {
          maxV = v;
        }
        if (v < minV) {
          minV = v;
        }
      }
    }
    if (maxV === minV) {
      maxV = minV + 1;
    }
    const range = maxV - minV;
    const yOf = (v: number): number => padT + plotH * (1 - (v - minV) / range);

    // 网格 + 纵轴刻度
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'right';
    for (let g = 0; g <= 4; g++) {
      const v = minV + range * g / 4;
      const y = yOf(v);
      ctx.strokeStyle = '#e0e0e0';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(padL, y);
      ctx.lineTo(w - padR, y);
      ctx.stroke();
      const t = Math.abs(v) >= 10000 ? `${(v / 10000).toFixed(1)}万` : `${Math.round(v)}`;
      ctx.fillStyle = '#999999';
      ctx.fillText(t, padL - 4, y + 4);
    }
    // 零轴线加粗
    if (minV < 0 && maxV > 0) {
      ctx.strokeStyle = '#666666';
      ctx.beginPath();
      ctx.moveTo(padL, yOf(0));
      ctx.lineTo(w - padR, yOf(0));
      ctx.stroke();
    }
    // 横轴月份
    ctx.textAlign = 'center';
    ctx.fillStyle = '#999999';
    for (let m = 1; m <= 12; m += 2) {
      const x = padL + plotW * (m - 1) / 11;
      ctx.fillText(`${m}月`, x, h - 8);
    }
    // 折线
    for (let i = 0; i < this.series.length; i++) {
      const line = this.series[i];
      if (line.length === 0) {
        continue;
      }
      ctx.strokeStyle = this.palette[i % this.palette.length];
      ctx.lineWidth = 2;
      ctx.beginPath();
      for (let m = 0; m < line.length; m++) {
        const x = padL + plotW * m / (line.length - 1);
        const y = yOf(line[m]);
        if (m === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.stroke();
    }
    // 图例
    ctx.textAlign = 'left';
    let lx = padL;
    for (let i = 0; i < this.labels.length && i < this.series.length; i++) {
      ctx.fillStyle = this.palette[i % this.palette.length];
      ctx.fillRect(lx, 2, 12, 4);
      ctx.fillStyle = '#333333';
      ctx.font = '11px sans-serif';
      ctx.fillText(this.labels[i], lx + 16, 8);
      lx += 16 + ctx.measureText(this.labels[i]).width + 20;
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(220)
      .onReady(() => this.onReadyCanvas())
  }
}
