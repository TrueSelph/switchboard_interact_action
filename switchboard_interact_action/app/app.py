"""This module renders the app for the switchboard interact action."""

import pandas as pd  # ✅ this is what you want
import streamlit as st
from jvclient.lib.utils import call_api, get_reports_payload
from jvclient.lib.widgets import app_controls, app_header, app_update_action
from streamlit_router import StreamlitRouter


def render(router: StreamlitRouter, agent_id: str, action_id: str, info: dict) -> None:
    """
    Renders the app for the switchboard interact action.

    :param router: The StreamlitRouter instance.
    :param agent_id: The agent ID.
    :param action_id: The action ID.
    :param info: A dictionary containing additional information.
    """

    # add app header controls
    (model_key, module_root) = app_header(agent_id, action_id, info)

    with st.expander("Switchboard Configuration", expanded=False):
        # Add main app controls
        app_controls(agent_id, action_id, hidden=["anchors", "functions", "weight"])
        # Add update button to apply changes
        app_update_action(agent_id, action_id)

    with st.expander("Subscriptions", True):

        if "current_page" not in st.session_state:
            st.session_state.current_page = 1
        if "per_page" not in st.session_state:
            st.session_state.per_page = 10
        if "target_agent" not in st.session_state:
            st.session_state.target_agent = []
        if "session_id" not in st.session_state:
            st.session_state.session_id = []

        list_payload = {
            "agent_id": agent_id,
            "page": st.session_state.current_page,
            "limit": st.session_state.per_page,
            "session_ids": st.session_state.session_id,
            "agent_name": st.session_state.target_agent,
        }

        list_result_data = call_api(
            endpoint="action/walker/switchboard_interact_action/list_subscriptions_walker",
            json_data=list_payload,
        )

        if list_result_data and list_result_data.status_code == 200:
            list_result_data = get_reports_payload(list_result_data)
            # st.write(list_result_data)
            if list_result_data:

                st.session_state.payload = list_result_data.copy()
                st.session_state.subs = st.session_state.payload["user_subscription"]
                st.session_state.sessions = st.session_state.payload["sessions"]
                st.session_state.agents = st.session_state.payload["agent_name"]

                total_items = st.session_state.payload.get("total_items", 0)
                total_pages = st.session_state.payload.get("total_pages", 0)

                # Inline row management (delete button per row)
                st.subheader("Subscriptions")
                col1, col2, col3 = st.columns(3)

                with col1:
                    prev_batch_filter = st.session_state.target_agent
                    # Batch ID filter - empty by default shows all

                    # Sort agents by name
                    agent_options = sorted(
                        st.session_state.agents, key=lambda x: x["name"]
                    )

                    # Use agent names for the multiselect display
                    batch_filter = st.multiselect(
                        "Filter by Agent",
                        options=[a["name"] for a in agent_options],
                        # default=(
                        #     [prev_batch_filter] if prev_batch_filter else []
                        # ),
                        default=prev_batch_filter if prev_batch_filter else [],
                    )
                    st.session_state.target_agent = batch_filter
                    # If agent changed, trigger a rerun
                    if batch_filter != prev_batch_filter:
                        st.rerun()

                with col2:
                    prev_batch_filter = st.session_state.session_id
                    # Batch ID filter - empty by default shows all
                    batch_filter = st.multiselect(
                        "Filter by Session",
                        options=sorted(st.session_state.sessions),
                        default=(
                            st.session_state.session_id
                            if st.session_state.session_id
                            else []
                        ),
                    )
                    st.session_state.session_id = batch_filter
                    # If session_id changed, trigger a rerun
                    if batch_filter != prev_batch_filter:
                        st.rerun()

                with col3:
                    # Store previous per_page value
                    prev_per_page = st.session_state.per_page

                    # Per-page selection dropdown
                    per_page = st.selectbox(
                        "Items per page",
                        options=[5, 10, 20, 50, 100, 200],
                        index=[5, 10, 20, 50, 100, 200].index(
                            st.session_state.per_page
                        ),
                        key="per_page_selector",
                        on_change=lambda: setattr(st.session_state, "current_page", 1),
                    )
                    # Update per_page in session state
                    st.session_state.per_page = per_page

                    # If per_page changed, trigger a rerun
                    if per_page != prev_per_page:
                        st.rerun()

                if st.session_state.subs:

                    df = pd.DataFrame(
                        [
                            {
                                "Agent": s["selected_agent_name"],
                                "User": s["user_session_id"],
                            }
                            for s in st.session_state.subs
                        ]
                    )

                    st.table(df)

                    col1, col2, col3 = st.columns([2, 4, 2])

                    with col1:
                        if st.session_state.current_page > 1:
                            if st.button("⬅️ Previous Page"):
                                st.session_state.current_page -= 1
                                st.rerun()
                        else:
                            st.button("⬅️ Previous Page", disabled=True)

                    with col2:
                        st.markdown(
                            f"<div style='text-align: center;'>Showing {len(st.session_state.subs)} of {total_items} messages (Page {st.session_state.current_page} of {total_pages})</div>",
                            unsafe_allow_html=True,
                        )

                    with col3:
                        if len(st.session_state.subs) >= st.session_state.per_page:
                            if st.button("Next Page ➡️"):
                                st.session_state.current_page += 1
                                st.rerun()
                        else:
                            st.button("Next Page ➡️", disabled=True)
                else:
                    st.info("No subscriptions available.")
            else:
                st.info("No subscriptions available.")
        else:
            st.info("No subscriptions available.")
