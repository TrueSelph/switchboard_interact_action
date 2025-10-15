import from datetime { datetime, timezone }
import from jivas.agent.core.graph_node { GraphNode }

node UserSubscription(GraphNode) {

    has subscribed_at: str = str(datetime.now(timezone.utc).isoformat());
    has updated_at: str = str(datetime.now(timezone.utc).isoformat());
    has user_session_id: str = "";
    has selected_agent_id: str = "";
    has selected_agent_name: str = "";
    has collection_id: str = "";


    def set_subscription(session_id: str, agent_id: str, agent_name: str) {
        self.user_session_id = session_id;
        self.selected_agent_id = agent_id;
        self.selected_agent_name = agent_name;
        self.updated_at = str(datetime.now(timezone.utc).isoformat());
        if (not self.subscribed_at) {
            self.subscribed_at = self.updated_at;
        }
    }

    def clear_subscription() {
        self.selected_agent_id = "";
        self.selected_agent_name = "";
        self.updated_at = str(datetime.now(timezone.utc).isoformat());
    }

    def export_data() -> dict {
        return {
            "node_id": self.id,
            "user_session_id": self.user_session_id,
            "selected_agent_id": self.selected_agent_id,
            "selected_agent_name": self.selected_agent_name,
            "subscribed_at": self.subscribed_at,
            "updated_at": self.updated_at
        };
    }
}