import "CoreLibs/graphics"
import "CoreLibs/animation"


local gfx <const> = playdate.graphics


PlayerAnimator = {}

function PlayerAnimator.new(framesByState, msByState)
    local a = {
        framesByState = framesByState,
        msByState = msByState or {},
        state = "idle",
        loop = nil
    }

    local function makeLoop(state)
        local frameMs = a.msByState[state] or 120
        a.loop = gfx.animation.loop.new(frameMs, a.framesByState[state], true)
    end

    function a:setState(state)
        if state ~= self.state or self.loop == nil then
            self.state = state
            makeLoop(state)
        end
    end

    function a:update(sprite, state, direction)
        self:setState(state)
        local flip = direction == -1 and gfx.kImageFlippedX or gfx.kImageUnflipped
        sprite:setImage(self.loop:image(), flip)
    end


    return a
end