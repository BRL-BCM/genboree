#!/usr/bin/env ruby

require 'inline'

class MyTest
   inline do |swalign|
    swalign.include ('<stdio.h>')
    swalign.include ('<stdlib.h>')
    swalign.include ('<pthread.h>')
    swalign.include ('<strings.h>')
    swalign.include ('<math.h>')
    swalign.add_compile_flags ('-O3 -lpthread')
    swalign.c_raw '
static VALUE task(VALUE *arg) {
  int i;
  double ff;
  ff = 2;
  for (i=0;i<10000000;i++) { 
    ff = exp(20+ff/exp(30));
    if ( (i+1)%100000 == 0) {
      printf("hello from %s\n", (char *)arg);
      fflush(stdout);
    }
  }
  return 0;
}
'
  swalign.c '
static int test_this() {
  pthread_t t1,t2;
  int i;
  
  
  for (i=0; i<10; i++) {
    if ( pthread_create(&t1, NULL, task, (void *)"1") != 0 ) {
      fprintf(stderr, "pthread_create() error\n");
      exit(1);
    }
    if ( pthread_create(&t2, NULL, task, (void *)"2") != 0 ) {
      fprintf(stderr, "pthread_create() error\n");
      exit(1);
    }
    task((void *)"3");
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);
  }
  return 0;
}
'
  end
end


##################
a = MyTest.new()
a.test_this()
