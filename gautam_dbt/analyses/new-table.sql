create table dbt_tutorial_dev.source.items
(
    id int,
    name string,
    category string,
    updateDate timestamp
);

insert into dbt_tutorial_dev.source.items values
(1, 'item1', 'category1', current_timestamp()),
(2, 'item2', 'category2', current_timestamp()),
(3, 'item3', 'category3', current_timestamp());

insert into dbt_tutorial_dev.source.items values
(3, 'item3_new', 'category3', current_timestamp());