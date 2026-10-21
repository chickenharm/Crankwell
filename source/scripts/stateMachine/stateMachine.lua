--- Minimal state machine. A state is any table with optional
--- enter(self, owner, ...), update(self, owner) and exit(self, owner) functions.
--- @class StateMachine
StateMachine = {}
class('StateMachine').extends()

function StateMachine:init(owner)
    self.owner = owner
    self.states = {}
    self.current = nil
    self.currentName = nil
end

function StateMachine:add(name, state)
    self.states[name] = state
end

function StateMachine:change(name, ...)
    local nextState = self.states[name]
    assert(nextState, "Unknown state: " .. tostring(name))

    if self.current and self.current.exit then
        self.current:exit(self.owner)
    end

    self.current = nextState
    self.currentName = name

    if nextState.enter then
        nextState:enter(self.owner, ...)
    end
end

function StateMachine:update()
    if self.current and self.current.update then
        self.current:update(self.owner)
    end
end