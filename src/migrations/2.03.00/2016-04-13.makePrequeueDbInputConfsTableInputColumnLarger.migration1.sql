/* This migration should be done on the prequeue DB (wherever it lives).
It increases the maximum size of a value in the input column (in the inputConfs table) from text (~64 kb) to mediumtext (~16 mb). */

use prequeue;
alter table inputConfs modify column input mediumtext NOT NULL ;
