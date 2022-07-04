BEGIN
  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(acl         => 'ACL_TEST.xml',
                                    description => 'ACL FOR TEST PURPOSES',
                                    principal   => [USER],--PUBLIC
                                    is_grant    => true,
                                    privilege   => 'connect',
                                    start_date  => null,
                                    end_date    => null );
                                      DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl       => 'ACL_TEST.xml',
                                       principal => [USER],
                                       is_grant  => false,
                                       privilege => 'connect',
                                       position  => 1);
                                          DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL (
                              acl        => 'ACL_TEST.xml',
                              host       => 'www.abc.com',
                              lower_port => null,
                              upper_port => null);
  COMMIT;
END;
