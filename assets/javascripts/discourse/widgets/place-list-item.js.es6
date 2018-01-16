import { createWidget } from 'discourse/widgets/widget';
import { iconNode } from 'discourse-common/lib/icon-library';
import DiscourseURL from 'discourse/lib/url';
import { h } from 'virtual-dom';

const rightContent = function(type, item) {
  if (type === 'event') {
    return moment(item.start).format('MM/DD');
  }
  if (type === 'rating') {
    return h('div', [
      h('span', [item.average_rating]),
      iconNode('star')
    ]);
  }
  if (type === 'petition') {
    return h('div', [
      h('span', [item.vote_count]),
      iconNode('check-square-o')
    ]);
  }
  if (type === 'group') {
    return h('div', [
      h('span', [item.user_count]),
      iconNode('user-o')
    ]);
  }
};

const itemTitle = function(type, item) {
  if (type === 'group') {
    return item.full_name;
  } else {
    return item.title;
  }
};

export default createWidget('place-list-item', {
  tagName: 'li.list-item',

  html(attrs) {
    const item = attrs.item;
    if (!item) return;

    const type = attrs.type;
    let contents = [];

    const right = rightContent(type, item);
    if (right) {
      contents.push(h('div.right', right));
    }

    contents.push(h('span.title', itemTitle(type, item)));

    return contents;
  },

  click() {
    DiscourseURL.routeTo(this.attrs.item.url);
  }
});
