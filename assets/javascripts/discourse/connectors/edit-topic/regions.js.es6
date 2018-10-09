import { getRegions } from '../../lib/place-utilities';

export default {
  setupComponent(attrs, component) {
    component.set('regions', getRegions(attrs.model.category));
  }
};
