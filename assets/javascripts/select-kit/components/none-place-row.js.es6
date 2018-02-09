export default Ember.Component.extend({
  tagName: 'li',
  layoutName: "select-kit/templates/components/none-place-row",
  classNameBindings: [ ":select-kit-row", ":place-row", "hidden"],
  hidden: Ember.computed.not('options.noContent'),

  click() {
    const filter = this.get('options.filter');
    this.appEvents.trigger("place-select:add-place", filter);
  }
});
