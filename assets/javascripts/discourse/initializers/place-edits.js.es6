import DiscoveryRoute from 'discourse/routes/discovery';
import DiscoveryController from 'discourse/controllers/discovery';
import DiscoveryTopicsController from 'discourse/controllers/discovery/topics';
import DiscourseURL from 'discourse/lib/url';
import Place from '../models/place';
import Topic from 'discourse/models/topic';
import TopicController from 'discourse/controllers/topic';
import { placeUrl, } from '../lib/place-utilities';
import { observes, on } from 'ember-addons/ember-computed-decorators';
import { withPluginApi } from 'discourse/lib/plugin-api';
import UserPlaceMixin from '../mixins/user-place';

export default {
  name: 'place-edits',
  initialize(){

    DiscoveryController.reopen(UserPlaceMixin);
    TopicController.reopen(UserPlaceMixin);

    DiscoveryTopicsController.reopen({
      canCreateTopicOnCategory: false,

      @observes('canCreateTopicOnCategory')
      resetCanCreateTOpicOnCategory() {
        this.set('canCreateTopicOnCategory', false);
      }
    });

    DiscoveryRoute.reopen({
      redirect() {
        const user = Discourse.User.current();

        if (user && user.admin) return;

        const path = window.location.pathname;
        if (path === "/" || path === "/categories") {
          DiscourseURL.routeTo(placeUrl(user));
        }
      }
    });

    withPluginApi('0.8.12', api => {
      api.modifyClass('component:site-header', {
        @on('init')
        @observes('currentUser.place_category_id')
        placeChanged() {
          const currentUser = this.get('currentUser');
          api.changeWidgetSetting('home-logo', 'href', placeUrl(currentUser));
          this.queueRerender();
        }
      });

      api.modifyClass('component:select-kit', {
        actions: {
          noContent() {
            this.didSelect();
            this.sendAction('noContent', this.get('filter'));
          }
        }
      });
    });

    Topic.reopen({
      @observes('category')
      setupPlace() {
        const category = this.get('category');
        const user = Discourse.User.current();

        if (!category || !user) return;

        if (category.place_can_join && user.place_category_id === category.id) {
          Place.create({ category_id: category.id }).then((result) => {
            this.setProperties({
              'place': result,
              'showActionBox': true
            });
          });
        }
      }
    });
  }
};
