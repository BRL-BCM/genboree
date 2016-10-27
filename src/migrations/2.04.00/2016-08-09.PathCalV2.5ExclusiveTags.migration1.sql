use cache;
delete from apiRespCache where rsrcPath rlike "^/REST/v1/grp/[^/]+/kb/[^/]+/coll/[^/]+/doc/.*\\?.*onClick=true.*transform=.*";
