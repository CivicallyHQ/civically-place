import { setPlace, resolvePlaceSet } from '../lib/place-utilities';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  type: Ember.computed.alias('model.place_type'),
  name: Ember.computed.alias('model.name'),

  @computed('type', 'name')
  title(type, name) {
    return I18n.t(`place.${type}.prompt`, { name });
  },

  @computed('type')
  description(type) {
    const changeMin = Discourse.SiteSettings[`place_${type}_change_min`];
    return I18n.t(`place.${type}.description`, { changeMin });
  },

  actions: {
    setPlace() {
      const categoryId = this.get('model.id');
      const type = this.get('type');

      this.set('loading', true);

      setPlace(categoryId, type).then((result) => {
        resolvePlaceSet(result);
      }).catch(popupAjaxError).finally(() => {
        window.location = '/';
      });
    }
  }
});
