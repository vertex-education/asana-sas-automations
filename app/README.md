# app/ (optional)

The sandbox includes a Streamlit console used during the build for viewing and editing assignment data. It is **not** on the critical path: the nightly sync runs entirely from `sql/` and the Snowflake task.

If the console is kept:

1. Copy the app source from the Snowsight Streamlit editor into this folder (e.g. `app/streamlit_app.py`).
2. Remove sandbox references (`MART_DB.BA_MLARSEN`) so it reads from the production schema.
3. Recreate it in production as the service role (the role has `CREATE STREAMLIT` from `admin/a1`).
4. Note: a Streamlit app runs with the owner's role context; users need Snowflake access to open it.

If it is not kept, leave this folder with only this README.
