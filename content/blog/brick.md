+++
title = "Making Rocket League Bot"
date = 2021-01-03
+++

- Introduce rocket league and RLBot
  - Physics-based, no auto-aim of any kind
  - Video/gif of good play and bad play
- Motivate the use of path planning / search
  - Describe series of moves required
- A\* Algorithm
- Hybrid A\* Algorithm
  - Grid needs to be dynamic :O
- Performance
  - Heuristic choice
  - Loosening the search process
- Conclusion
  - Expand to include aerials, more moves etc
  - There is a lot left out like simulating the car and ball correctly (see
    chip), handling aerials, etc
  - Link to brick

For the last few years, I've been obsessed with Rocket League, a physics-based
game where rocket-powered cars play soccer. Being physics-based means that this
game has an immensely high skill ceiling, not unlike sports in the physical
world.

The interaction between players and the game physics allows for amazing plays:

    TODO: gif

Or absolutely terrible plays, if you're more like the average player:

    TODO: gif

Given the difficulty of the game, the built-in AI isn't very good. Most
players can surpass it within weeks of playing, and must turn to playing against
other humans online for more of a challenge. I've always wondered how one might
build a better bot for Rocket League.

So when I discovered [RLBot](https://rlbot.org/), a framework and community
dedicated to making bots for Rocket League, I was thrilled! Finally, an
interesting side project!

## The Goal

Playing Rocket League well is a high bar. It involves predicting the motion of
the ball and other players, planning your moves and executing them,
positioning, strategizing and more. I'll settle for a much more modest
achievement: scoring a goal. More specifically, I would like to be able to hit
the ball into the goal from any starting point for the ball or car.

Solving this for certain positions does seem quite trivial. For example, if the
car is facing the ball and the ball is between the car and the goal already,
the car just needs to make a slight turn before driving straight at the ball.

But solving this in the general case is more challenging. Consider this case,
where one is pointing away from the ball, and ball is soaring high up in the air:

    TODO: gif

Scoring in this case requires a complex string of maneuvers:

1. Left turn on the ground
2. Driving straight up the wall
3. Jumping off at the appropriate moment
4. Flipping for additional horizontal velocity in the air
5. Boosting for more height and speed, while angling the car for correct
   positioning

And there are a variety of other situations requiring their own unique set of
moves in order to efficiently hit the ball in the desired direction. But given
an arbitrary scenario, where the car and ball may be anywhere on the field and
going at any speed, how can we figure out the right set of moves that will
accomplish our goal?

## You Can Turn Anything Into A Graph

Rocket League's phsyics update at 120fps, and thus player inputs are also
sampled at 120fps. Therefore, you could imagine that players are making 120
decisions per second and providing an appropriate input at each point. The
discrete steps could be made coarser, as needed for practicality, but we still
end up with a long string of decisions, which result in a string of moves that
hopefully cause a goal to be scored.

This looks awfully like a tree. At each branching point, there are a set of
different inputs that could be provided to the car. This tree reaches all
possible states the car could reach, and thus finding a solution can be thought
of as just a tree search.
