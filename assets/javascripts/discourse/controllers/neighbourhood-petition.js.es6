import { default as computed, on } from 'ember-addons/ember-computed-decorators';
import { cookAsync } from 'discourse/lib/text';

export default Ember.Controller.extend({
  searching: false,
  neighbourhoodTitle: '',

  @on('init')
  setup() {
    const userMin = Discourse.SiteSettings.place_neighbourhood_user_count_min;
    cookAsync(I18n.t('place.neighbourhood.petition.description', { userMin })).then((cooked) => {
      this.set('description', cooked);
    })
  },

  @computed('neighbourhoodTitle')
  noPetitions(title) {
    if (title) {
      return I18n.t("place.neighbourhood.petition.search.none_title", { title });
    } else {
      return I18n.t("place.neighbourhood.petition.search.none");
    }
  },

  actions: {
    startPetition() {
      this.set('loading', true);
      window.location.href = '/w/neighbourhood-petition';
    }
  }
})
