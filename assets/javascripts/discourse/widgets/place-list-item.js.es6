import { createWidget } from 'discourse/widgets/widget';
import { iconNode } from 'discourse-common/lib/icon-library';
import DiscourseURL from 'discourse/lib/url';
import { h } from 'virtual-dom';

const rightContent = function(listType, item) {
  if (listType === 'event') {
    return moment(item.start).format('MM/DD');
  }
  if (listType === 'rating') {
    return h('div', [
      h('span', [item.average_rating]),
      iconNode('star')
    ]);
  }
  if (listType === 'petition') {
    return h('div', [
      h('span', [item.vote_count]),
      iconNode('check-square-o')
    ]);
  }
  if (listType === 'group') {
    return h('div', [
      h('span', [item.user_count]),
      iconNode('user-o')
    ]);
  }
};

const itemTitle = function(listType, item) {
  if (listType === 'group') {
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

    const listType = attrs.listType;
    let contents = [];

    contents.push(h('span.title', itemTitle(listType, item)));

    const right = rightContent(listType, item);
    if (right) {
      contents.push(h('div.right', right));
    }

    return contents;
  },

  click() {
    DiscourseURL.routeTo(this.attrs.item.url);
  }
});
