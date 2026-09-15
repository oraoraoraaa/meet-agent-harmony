import mapSmokeTest from './MapSmoke.test';
import engineTest from '../../../test/Engine.test';

export default function testsuite(): void {
  engineTest();
  mapSmokeTest();
}
