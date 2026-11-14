import { useEffect, useState } from "react";
import {
  Background,
  BaseEdge,
  Controls,
  EdgeLabelRenderer,
  ReactFlow,
  getBezierPath,
  useEdgesState,
  useNodesState,
  type Edge,
  type EdgeProps,
  type Node,
  type NodeProps
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { Affix, Button, Descriptions, Space, message } from "antd";
import { PageHeader, StatusTag } from "../../components/admin";
import EntityEditModal from "./features/entity-edit-modal";
import StatusDialogs from "./features/status-dialogs";

// 画布页（判据正源: composition-layer.md 画布段；语法: react-antd.md 画布段）
// 入口只做装配（判据正源: references/page-splitting.md）：画布 + 伴随面板 + 状态栏；
// 弹框表单与状态栏附属浮层是封闭交互单元，落 features/
// 三区一体：画布主编辑面 + 伴随面板 + 底部状态栏；节点/边可选中驱动伴随面板

type EntityData = {
  identifier: string;
  label: string;
  description: string;
  primary: string;
};

type EntityFlowData = EntityData & { onPick: (id: string) => void };
type EntityNodeModel = Node<EntityFlowData, "entity">;
type RelationEdgeModel = Edge<{ label: string; onPick: (id: string) => void }, "relation">;

const ENTITIES: EntityData[] = [
  { identifier: "customer", label: "客户", description: "购买商品的个人或组织。", primary: "客户编号" },
  { identifier: "order", label: "订单", description: "一次购买的完整记录。", primary: "订单编号" },
  { identifier: "product", label: "商品", description: "订单中售卖的最小单元。", primary: "待补充" }
];

const NODE_POSITIONS: Record<string, { x: number; y: number }> = {
  customer: { x: 40, y: 80 },
  order: { x: 300, y: 40 },
  product: { x: 540, y: 130 }
};

const RELATIONS = [
  { id: "rel-customer-order", source: "entity-customer", target: "entity-order", label: "下单 · 1..n" },
  { id: "rel-order-product", source: "entity-order", target: "entity-product", label: "包含 · n..m" }
];

const ISSUES = [
  { target: "商品", text: "「商品」缺少主键属性" },
  { target: "订单", text: "「订单」到「商品」的关系未标注基数" }
];

function EntityNode({ id, data, selected }: NodeProps<EntityNodeModel>) {
  return (
    <div
      data-jjui-node={id}
      onClick={() => data.onPick(id)}
      className={`jjui-canvas__node${selected ? " jjui-canvas__node--selected" : ""}`}
    >
      <div className="jjui-canvas__node-title">{data.label}</div>
      <div className="jjui-canvas__node-desc">{data.description}</div>
    </div>
  );
}

function RelationEdge({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  data
}: EdgeProps<RelationEdgeModel>) {
  const [path, labelX, labelY] = getBezierPath({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition });
  return (
    <>
      <BaseEdge id={id} path={path} />
      <EdgeLabelRenderer>
        <span
          className="jjui-canvas__edge-label"
          data-jjui-edge={id}
          onClick={() => data.onPick(id)}
          style={{ transform: `translate(-50%, -50%) translate(${labelX}px, ${labelY}px)` }}
        >
          {data.label}
        </span>
      </EdgeLabelRenderer>
    </>
  );
}

const nodeTypes = { entity: EntityNode };
const edgeTypes = { relation: RelationEdge };

export default function CanvasEditor() {
  const [selectedId, setSelectedId] = useState("entity-customer");
  const [nodes, setNodes, onNodesChange] = useNodesState<EntityNodeModel>(
    ENTITIES.map((entity) => ({
      id: `entity-${entity.identifier}`,
      type: "entity" as const,
      position: NODE_POSITIONS[entity.identifier],
      data: { ...entity, onPick: setSelectedId }
    }))
  );
  const [edges, , onEdgesChange] = useEdgesState<RelationEdgeModel>(
    RELATIONS.map((relation) => ({
      id: relation.id,
      source: relation.source,
      target: relation.target,
      type: "relation" as const,
      data: { label: relation.label, onPick: setSelectedId }
    }))
  );
  const selectedEntity = nodes.find((node) => node.id === selectedId)?.data;
  // 发布/校验/历史：真实交互流（判据: composition-layer.md 页面段操作保真 + 画布段底部状态栏）
  const [published, setPublished] = useState(false);
  const [publishOpen, setPublishOpen] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  // 伴随面板编辑：弹框表单为封闭交互单元落 features/（判据正源: references/page-splitting.md），初始值经 props 下发
  const [editOpen, setEditOpen] = useState(false);
  const [editInitial, setEditInitial] = useState<{ label: string; description: string } | null>(null);

  const runCheck = () => {
    message.info(`校验完成：${ISSUES.length} 项待处理`);
  };
  const openEdit = () => {
    if (!selectedEntity) return;
    setEditInitial({ label: selectedEntity.label, description: selectedEntity.description });
    setEditOpen(true);
  };
  const submitEdit = (values: { label: string; description: string }) => {
    setNodes((prev) =>
      prev.map((node) =>
        node.id === selectedId ? { ...node, data: { ...node.data, label: values.label, description: values.description } } : node
      )
    );
    message.success(`已保存实体「${values.label}」（mock 数据）`);
    setEditOpen(false);
  };
  // StatusTag label 须为字面量状态词或纯变量（判据: composition-layer.md 状态段）
  const statusLabel = published ? "已发布" : "草稿";
  // 状态栏钉住目标：壳层内容滚动容器（判据: composition-layer.md 编辑器型页面段底部状态栏）
  const [scrollEl, setScrollEl] = useState<HTMLElement | null>(null);
  useEffect(() => {
    setScrollEl(document.querySelector(".admin-layout__content"));
  }, []);

  return (
    <main data-jjui-page="p-03">
      <PageHeader
        title="实体画布"
        description="以画布维护实体与关系，选中节点或边后在伴随面板编辑并查看校验。"
      />

      <div className="jjui-canvas" data-jjui-region="p-03.canvas">
        <div className="jjui-canvas__body">
          <div className="jjui-canvas__stage" data-jjui-canvas="p-03.canvas-stage">
            <ReactFlow
              nodes={nodes}
              edges={edges}
              onNodesChange={onNodesChange}
              onEdgesChange={onEdgesChange}
              nodeTypes={nodeTypes}
              edgeTypes={edgeTypes}
              fitView
            >
              <Background />
              <Controls />
            </ReactFlow>
          </div>

          <aside className="jjui-editor-panel" data-jjui-region="p-03.panel">
            <div className="jjui-section__title">{selectedEntity?.label}</div>
            <p className="jjui-section__description">{selectedEntity?.description}</p>
            <Descriptions
              column={1}
              size="small"
              bordered
              items={[
                { key: "identifier", label: "标识", children: selectedEntity?.identifier },
                { key: "primary", label: "主键", children: selectedEntity?.primary }
              ]}
            />
            <Button
              block
              style={{ marginTop: "var(--space-3)" }}
              data-jjui-action="p-03.edit-entity"
              onClick={openEdit}
            >
              编辑属性
            </Button>
            <div className="jjui-section__subtitle">校验</div>
            {ISSUES.map((issue) => (
              <p key={issue.text} className="jjui-section__description">{issue.text}</p>
            ))}
          </aside>
        </div>

        <Affix offsetBottom={0} target={() => scrollEl ?? undefined}>
          <footer className="jjui-editor-statusbar" data-jjui-region="p-03.statusbar">
            <Space size={12}>
              <StatusTag label={statusLabel} tone={published ? "success" : "info"} />
              <span className="jjui-pagination__meta">基线 v1.4 · {ISSUES.length} 项待处理校验</span>
            </Space>
            <Space size={8}>
              <Button size="small" data-jjui-action="p-03.canvas-check" onClick={runCheck}>校验</Button>
              <Button size="small" data-jjui-action="p-03.canvas-history" onClick={() => setHistoryOpen(true)}>版本历史</Button>
              <Button type="primary" size="small" data-jjui-action="p-03.canvas-publish" onClick={() => setPublishOpen(true)}>发布</Button>
            </Space>
          </footer>
        </Affix>
      </div>

      <EntityEditModal
        open={editOpen}
        initial={editInitial}
        onSubmit={submitEdit}
        onCancel={() => setEditOpen(false)}
      />
      <StatusDialogs
        publishOpen={publishOpen}
        historyOpen={historyOpen}
        onPublish={() => {
          setPublished(true);
          setPublishOpen(false);
          message.success("画布草稿已发布（mock 数据）");
        }}
        onPublishCancel={() => setPublishOpen(false)}
        onHistoryClose={() => setHistoryOpen(false)}
      />
    </main>
  );
}
