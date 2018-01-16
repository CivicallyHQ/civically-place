import Category from 'discourse/models/category';

let placeLabel = function(id, opts = {}) {
  const category = Category.findById(id);
  if (!category) return;

  let label = category.name;

  const parent = Category.findById(category.parent_category_id);
  if (parent) {
    label += `, ${parent.name}`;
  }

  if (opts.link) {
    label = `<a href=${category.get('url')}>${label}</a>`;
  }

  return label;
};

let placeTime = function(time) {
  return time ? moment(time).format('MMMM Do') : null;
};

let formatNum = function(num) {
  if (num) {
    return num.toLocaleString('en-US');
  } else {
    return 0;
  }
};

let placeUrl = function(user) {
  if (!user) return "/start";

  if (user.place_category_id) {
    const category = Category.findById(user.place_category_id);
    if (category) {
      const url = category.get('url');
      return url;
    }
  }

  if (user.place_topic_id) {
    return "/t/" + user.place_topic_id;
  }

  return '/place/set';
};

let categoryLabel = function(category) {
  if (!category) return '';
  let contents = `${category.name}`;
  return `<span class="category">${contents}</span>`;
};

export { placeUrl, placeLabel, placeTime, formatNum, categoryLabel };
