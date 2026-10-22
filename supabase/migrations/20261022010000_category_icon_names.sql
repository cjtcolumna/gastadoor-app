-- Categories now store a Flutter icon NAME (e.g. 'restaurant') and a color
-- NAME (e.g. 'orange') instead of an emoji. The app turns these names into
-- real icons and colors (see lib/features/categories/presentation/category_visuals.dart).
--
-- This updates categories that already exist: the starter set and the
-- sample-data ones. Categories with other names get a plain tag icon
-- in the app until we add a way to choose one.

update public.categories as c
set icon = v.icon,
    color = v.color
from (values
  ('expense', 'Food',      'restaurant',  'orange'),
  ('expense', 'Transport', 'bus',         'blue'),
  ('expense', 'Bills',     'receipt',     'amber'),
  ('expense', 'Shopping',  'shopping',    'pink'),
  ('expense', 'Health',    'health',      'red'),
  ('expense', 'Fun',       'celebration', 'purple'),
  ('expense', 'Other',     'category',    'grey'),
  ('expense', 'Coffee',    'cafe',        'brown'),
  ('income',  'Salary',    'work',        'green'),
  ('income',  'Gift',      'gift',        'teal'),
  ('income',  'Other',     'savings',     'indigo')
) as v(kind, name, icon, color)
where c.kind = v.kind
  and c.name = v.name;
