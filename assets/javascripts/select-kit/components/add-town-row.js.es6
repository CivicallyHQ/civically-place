import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

export default SelectKitRowComponent.extend({
  tagName: 'li',
  layoutName: "select-kit/templates/components/add-town-row",
  classNameBindings: [ ":select-kit-row", ":town-row", "hidden"],
  hidden: Ember.computed.not('options.noContent'),

  click() {
    this._super(...arguments);
    const filter = this.get('options.filter');
    this.appEvents.trigger("town-set:add-town", filter);
  }
});
