import { default as computed } from 'ember-addons/ember-computed-decorators';
import { setPlace, resolvePlaceSet } from '../lib/place-utilities';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Component.extend({
  classNames: ['town-set'],

  @computed('selectedId', 'currentId', 'loading')
  setDisabled(selectedId, currentId, loading) {
    return !selectedId || selectedId === currentId || loading;
  },

  @computed('type', 'currentUser.town_category_id', 'currentUser.neighbourhood_category_id')
  currentId(type, townId, neighbourhoodId) {
    return type === 'town' ? townId : neighbourhoodId;
  },

  @computed('type')
  noneRowComponent(type) {
    return `add-${type}-row`;
  },

  @computed('type')
  none(type) {
    return `place.${type}.placeholder`;
  },

  @computed('type')
  instructions(type) {
    return `place.${type}.instructions`;
  },
  
  actions: {
    setPlace(selectedId) {
      if (this.get('setDisabled')) return;

      const type = this.get('type');
      const categoryId = this.get(`currentUser.${type}_category_id`);

      this.set('loading', true);

      setPlace(selectedId, type).then((result) => {
        if (resolvePlaceSet(result) && this.get('routeAfterSet') && result.route_to) {
          this.set('loadingNewWindow', true);
          window.location = result.route_to;
        }
      }).catch(popupAjaxError).finally(() => {
        this.setProperties({
          loading: false,
          addingTown: false
        });
      });
    }
  }
});
