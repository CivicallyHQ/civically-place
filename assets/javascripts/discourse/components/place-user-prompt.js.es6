import showModal from "discourse/lib/show-modal";
import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  @computed('category', 'category.user_count', 'category.user_count_min')
  showPrompt(category, placeUserCount, placeUserCountMin) {
    return category && category.is_place &&
           category.place_type !== 'country' && placeUserCount < placeUserCountMin;
  },

  @computed('category')
  placeName(category) {
    return category.name;
  },

  actions: {
    openInvite() {
      showModal("invite", { model: this.currentUser });
    }
  }
})
