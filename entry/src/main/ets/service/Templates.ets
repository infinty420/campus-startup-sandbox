/**
 * V2 内置模板：动态成本条目 + 季节曲线 + 融资/阶段投资/阈值规则示例
 */
import { Plan, clonePlan, createCostItem, curveFlat, curveVacation, curveSemesterStart, curveExam } from '../model/PlanV2';

function tpl(name: string, type: string, setup: (p: Plan) => void): Plan {
  const p = clonePlan({
    id: '', version: 2, name: name, type: type, note: '',
    unitPrice: 0, dailyOrders: 0, daysPerMonth: 30, monthlyGrowthRate: 0, churnRate: 0,
    seasonCurve: curveFlat(), costItems: [], selfFunds: 0,
    loan: { amount: 0, annualRate: 6, months: 12 }, staged: [], stopLossMonths: 0,
    thresholds: [], staffCount: 1, areaSqm: 0
  }, name);
  p.type = type;
  setup(p);
  return p;
}

export function getTemplates(): Plan[] {
  const list: Plan[] = [];

  // 1. 奶茶档口：阈值规则示例（订单超 80 单/天加 1 名兼职）
  list.push(tpl('奶茶档口', '餐饮', (p: Plan) => {
    p.note = '食堂档口，主打 10 元价位；订单爆发需临时加人';
    p.unitPrice = 10;
    p.dailyOrders = 60;
    p.daysPerMonth = 30;
    p.monthlyGrowthRate = 5;
    p.seasonCurve = curveVacation();
    p.costItems.push(createCostItem('房租', 'monthly', 2500));
    p.costItems.push(createCostItem('人工工资', 'monthly', 4000));
    p.costItems.push(createCostItem('水电杂费', 'monthly', 600));
    p.costItems.push(createCostItem('营销费用', 'monthly', 500));
    const equip = createCostItem('设备购置', 'amortized', 18000);
    equip.amortMonths = 36;
    p.costItems.push(equip);
    const deco = createCostItem('装修', 'amortized', 8000);
    deco.amortMonths = 24;
    p.costItems.push(deco);
    p.costItems.push(createCostItem('押金', 'onetime', 5000));
    p.costItems.push(createCostItem('办证杂费', 'onetime', 500));
    p.costItems.push(createCostItem('原材料/包装', 'perUnit', 3.5));
    p.selfFunds = 31500;
    p.staffCount = 2;
    p.areaSqm = 10;
    p.stopLossMonths = 4;
    p.thresholds.push({ threshold: 80, addMonthlyCost: 2000, note: '订单超80单/天，加1名兼职' });
  }));

  // 2. 自助打印店：考试周旺季曲线
  list.push(tpl('自助打印店', '服务', (p: Plan) => {
    p.note = '宿舍区自助打印机，无人值守；期末旺季明显';
    p.unitPrice = 0.5;
    p.dailyOrders = 300;
    p.daysPerMonth = 26;
    p.monthlyGrowthRate = 2;
    p.seasonCurve = curveExam();
    p.costItems.push(createCostItem('房租', 'monthly', 1200));
    p.costItems.push(createCostItem('水电杂费', 'monthly', 400));
    p.costItems.push(createCostItem('营销费用', 'monthly', 100));
    const equip = createCostItem('打印机与耗材机', 'amortized', 15000);
    equip.amortMonths = 36;
    p.costItems.push(equip);
    const deco = createCostItem('简易布置', 'amortized', 2000);
    deco.amortMonths = 12;
    p.costItems.push(deco);
    p.costItems.push(createCostItem('押金', 'onetime', 2400));
    p.costItems.push(createCostItem('办证杂费', 'onetime', 200));
    p.costItems.push(createCostItem('纸张/墨粉', 'perUnit', 0.15));
    p.selfFunds = 19800;
    p.staffCount = 1;
    p.areaSqm = 8;
  }));

  // 3. 校园跑腿：借款融资示例（创业基金借款 1 万）
  list.push(tpl('校园跑腿', '服务', (p: Plan) => {
    p.note = '取快递/带饭跑腿，骑手按单提成；向学校创业基金借款 1 万启动';
    p.unitPrice = 4;
    p.dailyOrders = 40;
    p.daysPerMonth = 30;
    p.monthlyGrowthRate = 8;
    p.churnRate = 2;
    p.seasonCurve = curveVacation();
    p.costItems.push(createCostItem('骑手提成', 'monthly', 3000));
    p.costItems.push(createCostItem('通讯与保险', 'monthly', 100));
    p.costItems.push(createCostItem('地推物料', 'monthly', 300));
    const equip = createCostItem('电动车与保温箱', 'amortized', 2000);
    equip.amortMonths = 24;
    p.costItems.push(equip);
    p.costItems.push(createCostItem('平台抽成', 'perUnit', 0.5));
    p.selfFunds = 1000;
    p.loan = { amount: 10000, annualRate: 6, months: 12 };
    p.stopLossMonths = 3;
    p.staffCount = 4;
    p.areaSqm = 0;
  }));

  // 4. 二手书循环：阶段投资示例（9 月开学季补货）
  list.push(tpl('二手书循环', '零售', (p: Plan) => {
    p.note = '学期末收书、开学季卖出；9 月开学季追加一笔补货资金';
    p.unitPrice = 12;
    p.dailyOrders = 15;
    p.daysPerMonth = 25;
    p.monthlyGrowthRate = 3;
    p.seasonCurve = curveSemesterStart();
    p.costItems.push(createCostItem('房租', 'monthly', 800));
    p.costItems.push(createCostItem('人工工资', 'monthly', 1500));
    p.costItems.push(createCostItem('水电杂费', 'monthly', 100));
    p.costItems.push(createCostItem('营销费用', 'monthly', 200));
    p.costItems.push(createCostItem('货架', 'amortized', 1000));
    p.costItems.push(createCostItem('押金', 'onetime', 1600));
    p.costItems.push(createCostItem('收书成本', 'perUnit', 3));
    p.selfFunds = 2600;
    p.staged.push({ month: 9, amount: 3000 });
    p.staffCount = 2;
    p.areaSqm = 12;
  }));

  // 5. 家教中介：轻资产信息模式
  list.push(tpl('家教中介', '中介', (p: Plan) => {
    p.note = '撮合家长与同学，每单抽成 100 元，纯信息模式';
    p.unitPrice = 100;
    p.dailyOrders = 1;
    p.daysPerMonth = 30;
    p.monthlyGrowthRate = 10;
    p.churnRate = 3;
    p.seasonCurve = curveSemesterStart();
    p.costItems.push(createCostItem('推广获客', 'monthly', 800));
    p.costItems.push(createCostItem('通讯杂费', 'monthly', 50));
    p.costItems.push(createCostItem('建站/小程序摊销', 'amortized', 500));
    p.selfFunds = 1500;
    p.staffCount = 1;
    p.areaSqm = 0;
  }));

  return list;
}
