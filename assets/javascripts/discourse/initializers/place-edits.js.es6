import DiscoveryController from 'discourse/controllers/discovery';
import TopicController from 'discourse/controllers/topic';
import Category from 'discourse/models/category';
import PlaceMixin from '../mixins/place';
import DiscourseURL from 'discourse/lib/url';
import { placeUrl, } from '../lib/place-utilities';
import { ajax } from 'discourse/lib/ajax';
import { default as computed, observes, on } from 'ember-addons/ember-computed-decorators';
import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: 'place-edits',
  initialize(){

    DiscoveryController.reopen(PlaceMixin);
    TopicController.reopen(PlaceMixin);

    Category.reopenClass({
      setPlace(category_id, user_id = null) {
        let data = { category_id };
        if (user_id) data['user_id'] = user_id;
        return ajax('/place/set', { type: 'POST', data });
      }
    })

    withPluginApi('0.8.12', api => {
      api.modifyClass('controller:discovery/topics', {
        canCreateTopicOnCategory: false,

        @observes('canCreateTopicOnCategory')
        resetCanCreateTOpicOnCategory() {
          this.set('canCreateTopicOnCategory', false);
        }
      });

      api.modifyClass('route:discovery', {
        redirect() {
          const user = Discourse.User.current();

          if (user && user.admin) return;

          const path = window.location.pathname;
          if (path === "/" || path === "/categories") {
            DiscourseURL.routeTo(placeUrl(user));
          }
        }
      })

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
          },

          // Allows noneRow to display when select-kit has no contents
          highlight(rowComputedContent) {
            if (rowComputedContent) {
              this.set("highlightedValue", rowComputedContent.value);
              this._boundaryActionHandler("onHighlight", rowComputedContent);
            }
          }
        }
      });
    });
  }
};
