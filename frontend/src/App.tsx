import { BrowserRouter } from "react-router";
import { AppRouter } from "./app/router";

function App() {
  return (
    <BrowserRouter>
      <AppRouter />
    </BrowserRouter>
  );
}

export default App;
