% Enables users to add or remove their own knowledge bases.
% clear_knowledge_base needs this (because of retract).
:- dynamic student/2, available_slots/1, room_capacity/2.

% clear_knowledge_base.
% Removes all students, slots and rooms from prolog's mind
% also counts each type and writes this info.
clear_knowledge_base:-
  aggregate_all(count, retract(student(_, _)), StudentCount),
  format('~w ~d~n', ['student/2:', StudentCount]),
  aggregate_all(count, retract(available_slots(_)), SlotCount),
  format('~w ~d~n', ['available_slots/1:', SlotCount]),
  aggregate_all(count, retract(room_capacity(_, _)), RoomCount),
  format('~w ~d~n', ['room_capacity/2:', RoomCount]).

% all_students( −StudentList ).
% Produces a list which contains all students in a knowledge base.
all_students(StudentList):-
  findall(StudentID, student(StudentID, _), StudentList).

% all_courses( −CourseList ).
% Produces a list which contains all unique courses in a knowledge base.
% First combines the lists of courses of each student into a new list,
% then sorts (removes duplicates) this list.
all_courses(CourseList):-
  findall(CourseIDs, student(_, CourseIDs), ListOfLists),
  append(ListOfLists, List),
  sort(List, CourseList).

% all_members( +CourseID, -MemberList)
% Produces a list which contains all students who takes this course.
% Helper method for student_count and common_students.
% First gets each student's list of courses,
% then controls whether the given course is in this list or not.
all_members(CourseID, MemberList):-
  findall(StudentID, (student(StudentID, List), member(CourseID, List)), MemberList).

% student_count( +CourseID, −StudentCount ).
% Gives the total number of students who takes this course.
% First takes the course list from helper method, then finds the length of this list.
student_count(CourseID, StudentCount):-
  all_members(CourseID, MemberList),
  length(MemberList, StudentCount).

% common_students( +CourseID1, +CourseID2, −StudentCount ).
% Gives the total number of students who takes both of these courses.
% First takes two course lists from helper method, then intersects these lists
% (to find which students take both of these courses), at last finds the length of this new list.
common_students(CourseID1, CourseID2, StudentCount):-
  all_members(CourseID1, MemberList1),
  all_members(CourseID2, MemberList2),
  intersection(MemberList1, MemberList2, CommonMembers),
  length(CommonMembers, StudentCount).

% final_plan( -FinalPlan).
% Gives a final plan without any conflicts or errors.
final_plan(FinalPlan):-
  all_courses(CourseList),
  findall([RoomID, SlotID], (room_capacity(RoomID, _), available_slots(Slots), member(SlotID, Slots)), PairList),
  finals(CourseList, PairList, [], FinalPlan).

% finals( +CourseList, +PairList, +Accumulator, -FinalPlan).
% Base case for the recursion of finding final plans.
% When there is no course left to be added to final plan,
% all the accumulated exams are converted to the whole final plan
% then this plan is returned in all recursive cases.
finals([], _, Accumulator, FinalPlan):-
  FinalPlan = Accumulator.

% finals( +CourseList, +PairList, +Accumulator, -FinalPlan).
% Recursive case for the recursion of finding final plans.
finals([CourseID|CourseList], PairList, Accumulator, FinalPlan):-
  % First, chooses a room with enough capacity for the course.
  (
    member(Pair, PairList),
    Pair = [RoomID, SlotID],
    student_count(CourseID, Count),
    room_capacity(RoomID, Capacity),
    Capacity >= Count
  ),
  % Then chooses a slot such that finals in the plan
  % containing this slot does not have mapped to any course in plan
  % such that this course does not have any common students with the current course.
  forall(member([Conflict, _, SlotID], Accumulator), (common_students(CourseID, Conflict, Common), Common == 0)),
  % Then deletes this room-slot pair list to prevent conflicts
  % and adds this final to the accumulated plan before going deeper.
  (
    delete(PairList, Pair, NewPairList),
    append(Accumulator, [[CourseID, RoomID, SlotID]], NewAccumulator),
    finals(CourseList, NewPairList, NewAccumulator, FinalPlan)
  ).

% errors_for_plan( +FinalPlan, -Errors).
% Gives the total number of errors in a given final plan.
errors_for_plan(FinalPlan, Errors):-
  errors(FinalPlan, Errors).

% errors( +FinalPlan, -Errors).
% Base case for the recursion of finding errors in a given final plan.
% When there is no final left to be analyzed error count set to zero
% then it is incremented in recursive cases if it is necessary.
errors([], 0).

% errors( +FinalPlan, -NewErrors).
% Recursive case for the recursion of finding errors in a given final plan.
errors([[CourseID, RoomID, SlotID]|FinalPlan], NewErrors):-
  % Goes deeper until base case, then returns zero from there and adds the errors to this zero.
  errors(FinalPlan, OldErrors),
  % Checks whether the course has assigned to a room with enough capacity,
  % if there is not enough capacity then adds the overflow to the errors.
  (
    student_count(CourseID, Count),
    room_capacity(RoomID, Capacity),
    Count > Capacity -> Errors is OldErrors + Count - Capacity ; Errors is OldErrors
  ),
  % Checks whether there is a course such that
  % it has common students with the current course and it has assigned to the current slot in the final plan,
  % if there is then adds the number of common students to the errors.
  (
    findall(Common, (member([Conflict, _, SlotID], FinalPlan), common_students(CourseID, Conflict, Common)), Commons),
    sum_list(Commons, Total),
    NewErrors is Errors + Total
  ).