import logging;
import from logging { Logger }
import from jivas.agent.core.agent { Agent }
import from jivas.agent.action.action { Action }
import from jivas.agent.action.actions { Actions }
import from jivas.agent.modules.action.path { action_walker_path }
import from jivas.agent.action.agent_graph_walker { agent_graph_walker }

walker remove_subscription_walker(agent_graph_walker) {
    has user_session_id: str = "";

    has response: dict = {};
    has reporting:bool = True;

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    class __specs__ {
        static has private: bool = False;
        static has path: str = action_walker_path(__module__);
    }

    can on_agent with Agent entry {
        visit [-->](`?Actions);
    }
    can on_actions with Actions entry {
        visit [-->](`?Action)(?enabled==True)(?label=='SwitchboardInteractAction');
    }
    can on_action with Action entry {
        success = here.remove_user_location_subscription(
            user_session_id=self.user_session_id
        );
        if (success) {
            self.response = {"status": "succeeded", "message": "Subscription removed successfully (or was not found)."};
        } else {
            self.response = {"status": "failed", "message": "Failed to remove subscription (an error may have occurred)."};
        }

        if (self.reporting) {
            report self.response;
        }
    }
}