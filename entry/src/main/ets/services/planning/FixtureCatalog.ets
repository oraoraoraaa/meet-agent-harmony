import {
  Constraints,
  MODE_BICYCLE,
  MODE_TRANSIT,
  MODE_WALKING,
  NamedPoint
} from '../../domain/Models';

export class FixtureScenario {
  id: string = '';
  title: string = '';
  city: string = '';
  driver: NamedPoint = new NamedPoint();
  passenger: NamedPoint = new NamedPoint();
  constraints: Constraints = new Constraints();
  narrationZh: string = '';
}

/**
 * In-app fixtures (mirrored from fixtures/scenarios/*.json).
 * Keeps Mode C demo independent of raw asset packaging.
 */
export class FixtureCatalog {
  static all(): FixtureScenario[] {
    return [FixtureCatalog.xian(), FixtureCatalog.shanghai()];
  }

  static byId(id: string): FixtureScenario {
    const all: FixtureScenario[] = FixtureCatalog.all();
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === id) {
        return all[i];
      }
    }
    return FixtureCatalog.xian();
  }

  private static xian(): FixtureScenario {
    const f: FixtureScenario = new FixtureScenario();
    f.id = 'xian-demo-1';
    f.title = '西安：高新 → 钟楼';
    f.city = '西安';
    f.driver = new NamedPoint(108.8905, 34.2324, '司机起点（高新）', '');
    f.passenger = new NamedPoint(108.9465, 34.2610, '乘客（钟楼附近）', '');
    f.constraints.allowedModes = [MODE_WALKING, MODE_BICYCLE, MODE_TRANSIT];
    f.constraints.maxPassengerWalkMin = 12;
    f.constraints.avoidTransit = false;
    f.constraints.notes = 'demo fixture';
    f.narrationZh = '司机从高新区出发接钟楼附近乘客，可骑行。';
    return f;
  }

  private static shanghai(): FixtureScenario {
    const f: FixtureScenario = new FixtureScenario();
    f.id = 'shanghai-demo-1';
    f.title = '上海：陆家嘴 → 人民广场';
    f.city = '上海';
    f.driver = new NamedPoint(121.5086, 31.2454, '司机起点（陆家嘴）', '');
    f.passenger = new NamedPoint(121.4737, 31.2304, '乘客（人民广场）', '');
    f.constraints.allowedModes = [MODE_WALKING, MODE_BICYCLE, MODE_TRANSIT];
    f.constraints.maxPassengerWalkMin = 10;
    f.constraints.avoidTransit = false;
    f.constraints.notes = 'demo fixture';
    f.narrationZh = '陆家嘴出发接人民广场乘客。';
    return f;
  }
}
