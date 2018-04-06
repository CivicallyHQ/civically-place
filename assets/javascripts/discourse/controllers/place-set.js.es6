import Sidebars from 'discourse/plugins/discourse-layouts/discourse/mixins/sidebars';

export default Ember.Controller.extend(Sidebars, {
  mainContent: 'placeSet',
  showCategoryAdmin: false,
  showCategoryEditBtn: false,
  leftSidebarEnabled: false,
  rightSidebarEnabled: true
});
